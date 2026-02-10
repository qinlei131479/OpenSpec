import datetime
from playhouse.pool import PooledMySQLDatabase
from peewee import Model, CharField, DateTimeField

# 本地测试，支持从 .env 文件读取数据库配置
import os
from dotenv import load_dotenv
load_dotenv()
db_config = {
    'host': os.getenv('MYSQL_HOST'),
    'user': os.getenv('MYSQL_USER'),
    'password': os.getenv('MYSQL_PASSWORD'),
    'database': os.getenv('MYSQL_DATABASE')
}

# 创建连接池，增加连接池参数，防止长时间连接失效
db = PooledMySQLDatabase(
    **db_config,
    max_connections=20,      # 可根据实际情况调整
    stale_timeout=300        # 连接最大空闲秒数，超时自动重连（如5分钟）
)

# 定义模型

class ProjectKnowledgebaseRelation(Model):
    project_id = CharField(max_length=50, primary_key=True)
    knowledgebase_id = CharField(max_length=32)
    creator_id = CharField(max_length=50)
    operation_time = DateTimeField()
    api_key = CharField(max_length=60)
    agent_id = CharField(max_length=50, null=True)

    class Meta:
        database = db
        table_name = 'project_knowledgebase_relation'
        primary_key = False  # 禁用自动 id 字段

def get_agent_id_by_project_id(project_id):
    """根据 project_id 查询 agent_id"""
    try:
        with db.connection_context():
            relation = ProjectKnowledgebaseRelation.get(ProjectKnowledgebaseRelation.project_id == project_id)
            return relation.agent_id
    except ProjectKnowledgebaseRelation.DoesNotExist:
        return None
    except Exception as e:
        # 增加异常捕获，防止连接丢失导致服务崩溃
        print(f"Error getting agent_id from DB: {e}")
        return None
    

def get_api_key_by_project_id(project_id):
    """根据 project_id 查询 agent_id"""
    try:
        with db.connection_context():
            relation = ProjectKnowledgebaseRelation.get(ProjectKnowledgebaseRelation.project_id == project_id)
            return relation.api_key
    except ProjectKnowledgebaseRelation.DoesNotExist:
        return None
    except Exception as e:
        # 增加异常捕获，防止连接丢失导致服务崩溃
        print(f"Error getting agent_id from DB: {e}")
        return None

def get_kb_id_by_project_id(project_id):
    """根据 project_id 查询 knowledgebase_id"""
    try:
        with db.connection_context():
            relation = ProjectKnowledgebaseRelation.get(ProjectKnowledgebaseRelation.project_id == project_id)
            return relation.knowledgebase_id
    except ProjectKnowledgebaseRelation.DoesNotExist:
        return None
    except Exception as e:
        print(f"Error getting kb_id from DB: {e}")
        return None