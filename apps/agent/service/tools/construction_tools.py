"""
建筑施工文档生成工具集
基于 RAGFlow 知识库检索
"""
import os
import sys
import json
from contextvars import ContextVar
from langchain_core.tools import tool
from ragflow_sdk import RAGFlow
from dotenv import load_dotenv

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from utils.logger import get_logger

load_dotenv()
logger = get_logger('construction_tools')

# RAGFlow 配置信息
RAGFLOW_BASE_URL = os.getenv("RAGFLOW_BASE_URL", "")
RAGFLOW_API_KEY = os.getenv("RAGFLOW_API_KEY")

# 知识库 ID 配置
# 注意：这里使用固定的知识库 ID，也可以通过 project_id 动态查询
try:
    STAND_KB_IDS = json.loads(os.getenv("DEFAULT_STAND_KB_IDS", "[]"))  # 行业规范库 (可选配置)
except Exception:
    raise ValueError("未找到知识库配置: DEFAULT_STAND_KB_IDS 解析失败")
try:
    CASE_KB_IDS = json.loads(os.getenv("DEFAULT_CASE_KB_IDS", "[]"))   # 企业案例库 (可选配置)
except Exception:
    raise ValueError("未找到知识库配置: DEFAULT_CASE_KB_IDS 解析失败")

# =============================================================================
# 请求级知识库 ID（通过 contextvars 实现，线程/协程安全）
# 在 API 入口根据标签解析出 KB IDs 后设置，检索工具优先使用 context 中的值
# =============================================================================
_request_case_kb_ids: ContextVar[list] = ContextVar('case_kb_ids', default=None)
_request_stand_kb_ids: ContextVar[list] = ContextVar('stand_kb_ids', default=None)


def set_request_kb_ids(case_ids: list = None, standard_ids: list = None):
    """设置当前请求的知识库 ID（请求级，不影响全局）"""
    if case_ids is not None:
        _request_case_kb_ids.set(case_ids)
        logger.info(f"[ContextVar] 设置请求级案例库: {case_ids}")
    if standard_ids is not None:
        _request_stand_kb_ids.set(standard_ids)
        logger.info(f"[ContextVar] 设置请求级规范库: {standard_ids}")


def clear_request_kb_ids():
    """清除当前请求的知识库 ID（在请求结束时调用）"""
    _request_case_kb_ids.set(None)
    _request_stand_kb_ids.set(None)
    logger.debug("[ContextVar] 已清除请求级知识库")


def _retrieve_from_kb(query: str, kb_ids: list, kb_name: str = "知识库") -> str:
    """
    通用检索函数（优化版）

    Args:
        query: 检索关键词或问题
        kb_ids: 知识库 ID 列表
        kb_name: 知识库名称（用于日志）

    Returns:
        str: 检索到的内容拼接字符串，包含来源和相关度信息
    """
    if not kb_ids:
        return f"未配置{kb_name}，无法检索。"

    logger.info(f"[RAGFlow] Retrieving from {kb_name}: {query[:50]}...")
    try:
        rag_object = RAGFlow(api_key=RAGFLOW_API_KEY, base_url=RAGFLOW_BASE_URL)
        chunks = rag_object.retrieve(
            question=query,
            dataset_ids=kb_ids,
            page=1,
            page_size=10,  # 增加返回数量
            similarity_threshold=0.55  # 适当提高阈值
        )

        if chunks:
            context_list = []
            for chunk in chunks:
                # 提取内容
                if hasattr(chunk, 'content_with_weight'):
                    content = chunk.content_with_weight
                elif hasattr(chunk, 'content'):
                    content = chunk.content
                elif isinstance(chunk, dict):
                    content = chunk.get('content_with_weight', chunk.get('content', str(chunk)))
                else:
                    content = str(chunk)

                # 提取来源和相关度信息
                source = getattr(chunk, 'document_name', None) or \
                         (chunk.get('document_name') if isinstance(chunk, dict) else None) or \
                         '未知来源'
                score = getattr(chunk, 'similarity', None) or \
                        (chunk.get('similarity') if isinstance(chunk, dict) else None) or \
                        0.0

                # 格式化输出
                formatted = f"【来源: {source} | 相关度: {score:.2f}】\n{content}"
                context_list.append(formatted)

            logger.debug(f"[RAGFlow] Retrieved {len(context_list)} chunks from {kb_name}")
            return "\n\n---\n\n".join(context_list)
        logger.warning(f"[RAGFlow] No relevant content found in {kb_name}")
        return f"未检索到相关{kb_name}内容。"
    except Exception as e:
        logger.error(f"[RAGFlow] Retrieval failed from {kb_name}: {e}", exc_info=True)
        return f"检索失败: {e}"


@tool
def retrieve_case(query: str) -> str:
    """
    从知识库检索建筑施工设计说明历史案例。

    Args:
        query: 检索关键词或问题

    Returns:
        str: 检索到的案例内容拼接字符串
    """
    kb_ids = _request_case_kb_ids.get() or CASE_KB_IDS
    return _retrieve_from_kb(query, kb_ids, "案例库")


@tool
def retrieve_standard(query: str) -> str:
    """
    从知识库检索建筑施工行业规范。

    Args:
        query: 检索关键词或问题

    Returns:
        str: 检索到的规范内容拼接字符串
    """
    kb_ids = _request_stand_kb_ids.get() or STAND_KB_IDS
    return _retrieve_from_kb(query, kb_ids, "规范库")


def retrieve_from_project_kb(query: str, project_id: str) -> str:
    """
    根据项目 ID 动态查询知识库并检索

    Args:
        query: 检索关键词或问题
        project_id: 项目 ID

    Returns:
        str: 检索到的内容拼接字符串
    """
    from service.db.database import get_kb_id_by_project_id

    kb_id = get_kb_id_by_project_id(project_id)
    if not kb_id:
        return f"项目 {project_id} 未关联知识库，无法检索。"

    return _retrieve_from_kb(query, [kb_id], f"项目知识库 ({kb_id})")

