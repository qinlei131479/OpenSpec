<script setup lang="ts">
import { ref, onMounted, nextTick, computed, watch }from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElNotification, ElMessage, ElMessageBox, ElCollapseTransition, ElDropdown, ElDropdownMenu, ElDropdownItem, genFileId } from 'element-plus'
import type { Action, UploadInstance, UploadProps, UploadRawFile } from 'element-plus'
import { 
  Plus,
  Setting,
  Document,
  CircleCheck,
  ArrowRight,
  Star,
  Close,
  Delete,
  Check,
  Sort,
  SwitchButton,
  UploadFilled,
  ChatDotRound,
  MagicStick
} from '@element-plus/icons-vue'
import HeaderLogo from '../components/HeaderLogo.vue'
import DocumentList from '../components/DocumentList.vue'
import DocumentOutline from '../components/DocumentOutline.vue'
import MarkdownEditor from '../components/MarkdownEditor.vue'
import RecognizeResultDrawer from '../components/RecognizeResultDrawer.vue'
import ChatAssistant from '../components/ChatAssistant.vue'
import { 
  docMetaData as mockDocMetaData,
  knowledgeBaseList as mockKnowledgeBaseList,
  mockOperationRecord,
  outlineTemplate,
  type DocumentItem,
  type ProjectInfo,
  chapterTemplateMap,
  promptParamsByTitle
} from '../data/mockData'

import { parse2Json, parseSecondaryHeadings } from '../utils/convert'
import { generateDocumentTags } from '../utils/projectInfo'
import { downloadFile } from '../utils/document'

import { createDocument, renameDocument as renameDocumentApi, deleteDocument as deleteDocumentApi, getDocumentList, batchCreateDocumentBlocks, getDocumentBlocks, getDocumentBlockDetail, updateDocumentBlock, exportDocumentMarkdown } from '../service/document';
import { importToAutoCAD } from '../service/localCad';
import {
  generateOutlineWithAssistant,
  generateParagraphStream,
  generateParagraph,
  generateParagraphBatch,
  uploadAndParseFile,
  uploadFile,
  parseFile,
  extractKey,
  type RagflowResponse
} from '../service/ragflow';
import { getChineseNumber,processRecognitionResult, resetProjectForm } from '../utils/common'
import { useLogout } from '../composables/useLogout'
import { authStorage } from '../utils/auth'
import { hasTemplateManagementLicense } from '../service/license'

const route = useRoute()
const router = useRouter()

// 退出登录
const { logout } = useLogout()
const userInfo = computed(() => authStorage.getUserInfo())
// 获取用户ID，用于文档操作
// 优先使用 name（用户名），其次使用 email，最后使用 id
const userId = computed(() => {
  const name = userInfo.value?.name
  const email = userInfo.value?.email
  const id = userInfo.value?.id

  // 优先返回用户名（如 'dby'），便于在 Langfuse 中识别
  const finalUserId = name || email || id || ''

  if (!finalUserId) {
    console.warn('用户ID不存在，请先登录')
  }

  return finalUserId
})

// 处理用户下拉菜单命令
const handleUserCommand = async (command: string) => {
  if (command === 'logout') {
    await logout()
  } else if (command === 'qa') {
    router.push('/qa')
  } else if (command === 'settings') {
    // 检查模板管理授权
    const hasLicense = await hasTemplateManagementLicense()
    if (hasLicense) {
      router.push('/settings')
    } else {
      ElMessageBox.alert(
        '模板管理功能需要企业版授权，请联系我们升级到企业版。',
        '升级到企业版',
        {
          confirmButtonText: '我知道了',
          type: 'warning'
        }
      )
    }
  }
}

// 响应式数据
const documentTitle = ref('某商业综合体施工设计说明')
const isModified = ref(false)

// 欢迎页状态
const showWelcomePage = ref(true) // 默认显示欢迎页
const hasActiveDocument = ref(false) // 是否有活动文档

// 文档数据（按最后修改时间降序排列）
const documents = ref<DocumentItem[]>([])
const loadingDocuments = ref(false)

// 文档排序函数
const sortDocumentsByDate = () => {
  documents.value.sort((a, b) => {
    const dateA = new Date(a.lastModified)
    const dateB = new Date(b.lastModified)
    return dateB.getTime() - dateA.getTime() // 降序排列，最新的在前
  })
}

const editingDocumentId = ref('')
const editingDocumentName = ref('')
const showRenameDialog = ref(false)

// 项目信息表单数据
const projectForm = ref<ProjectInfo>(resetProjectForm())
const wizardForm = ref<ProjectInfo>(resetProjectForm())

// AI配置相关
const showConfigPanel = ref(false)
const chatAssistantWidth = ref(380)

const handleChatResize = (newWidth: number) => {
  chatAssistantWidth.value = Math.max(300, Math.min(newWidth, 800))
}

const isResizingChat = ref(false)

const editorContainerStyle = computed(() => ({
  '--chat-width': `${chatAssistantWidth.value}px`
}))

const isOutlineCollapsed = ref(false)
const currentDocumentId = ref('')
const currentBlockContent = ref('')
const currentBlockId = ref('') // 当前编辑的 blockId，用于保存
const isServerDoc = computed(() => !!currentDocumentId.value)
const inGenerating = ref(false) // 生成状态

const abortGenerate = () => {
  inGenerating.value = false
  // TODO: Implement actual abort logic
}

// 章节数据（从后端 blocks 拉取填充）
const chapters = ref<any[]>([])

// 当前选中的章节ID，默认为第一个章节
const currentChapterId = ref('')

// 引用资料折叠状态
const isReferenceMaterialsExpanded = ref(false)

// 底部面板 tab 切换：'reference' | 'operation'
const activeBottomTab = ref<'reference' | 'operation'>('reference')

// 处理章节点击事件
const handleChapterClick = async (chapterId: string) => {
  // 若正在生成内容，先提示用户确认是否中断并切换
  if (inGenerating.value) {
    try {
      await ElMessageBox.confirm(
        '当前正在生成内容，切换章节将中断生成。是否继续？',
        '确认切换',
        {
          type: 'warning',
          confirmButtonText: '中断并切换',
          cancelButtonText: '取消'
        }
      )
      // 用户确认：先中断当前生成，再继续切换
      abortGenerate()
    } catch {
      // 用户取消：不进行章节切换
      ElMessage.info('已取消切换，继续生成当前内容')
      return
    }
  }

  console.log('点击章节:', chapterId)
  // 更新当前选中的章节
  currentChapterId.value = chapterId
  scrollToChapter(chapterId)
  // 依据章节映射到的 blockId 获取内容
  try {
    const chapter = chapters.value.find(ch => ch.id === chapterId)
    // @ts-ignore 保留 blockId
    const blockId = chapter && (chapter as any).blockId
    // console.log('ccccccc chapter:', chapter, blockId)
    if (currentDocumentId.value && blockId) {
      currentBlockId.value = String(blockId) // 保存 blockId
      const res = await getDocumentBlockDetail(currentDocumentId.value, String(blockId))
      if (res.code === 200 && res.data) {
        currentBlockContent.value = res.data.content || ''
        // 更新当前章节的二级目录
        updateCurrentChapterSecondaryHeadings()
      }
    }
  } catch (e) {
    console.error('获取文档块内容失败:', e)
  }
}

// 处理章节折叠事件
const handleChapterCollapse = (chapterId: string, collapsed: boolean) => {
  const chapter = chapters.value.find(ch => ch.id === chapterId)
  if (chapter) {
    chapter.collapsed = collapsed
  }
}

// 处理大纲折叠事件
const handleOutlineToggle = (collapsed: boolean) => {
  isOutlineCollapsed.value = collapsed
  console.log('大纲折叠状态:', collapsed)
}

// 加载某文档的大纲（heading_1 blocks）
const loadDocumentOutline = async (documentId: string) => {
  try {
    const res = await getDocumentBlocks(documentId, { page: 1, pageSize: 1000, blockType: 'heading_1' })
    if (res.code === 200 && res.data) {
      const list = res.data.list || []
      
      // 并行加载每个章节的内容以解析二级标题
      const mapped = await Promise.all(
        list.map(async (blk: any, idx: number) => {
          const titleFromBlockName = (blk.blockName || '').toString().trim()
          const firstLine = (blk.content || '').split('\n')[0] || ''
          const title = titleFromBlockName || firstLine.replace(/^#+\s*/, '') || `章节 ${idx + 1}`
          
          // 获取章节的完整内容以解析二级标题
          let children: Array<{ id: string, title: string }> = []
          
          // 优先使用块列表中的 content，如果没有或为空，再调用 API
          let contentToParse = blk.content || ''
          
          if (!contentToParse && blk.id) {
            try {
              const detailRes = await getDocumentBlockDetail(documentId, String(blk.id))
              if (detailRes.code === 200 && detailRes.data && detailRes.data.content) {
                contentToParse = detailRes.data.content
              }
            } catch (e) {
              console.warn(`加载章节 ${idx + 1} 内容失败:`, e)
            }
          }
          
          // 从内容中解析二级标题
          const chapterId = String(idx + 1)
          if (contentToParse) {
            children = parseSecondaryHeadings(contentToParse, chapterId)
          }

          // 解析 docReference、chunkReference（可能是 JSON 字符串）
          const parsedDocReference = blk.docReference ? parse2Json(blk.docReference) : []
          const parsedChunkReference = blk.chunkReference ? parse2Json(blk.chunkReference) : []
          
          return { 
            id: chapterId, 
            title, 
            active: idx === 0, 
            collapsed: false, 
            blockId: blk.id,
            children: children.length > 0 ? children : undefined,
            docReference: parsedDocReference,
            chunkReference: parsedChunkReference
          }
        })
      )
      
      chapters.value = mapped
      // 同步：根据 mapped 生成 totalDocObjects
      const newDocObjects = mapped.map((ch: any) => ({
        id: Number(ch.id),
        chapterId: `chapter-${ch.id}`,
        type: 'chapter',
        title: ch.title,
        hasContent: false,
        loading: false,
        actions: ['generate'],
        children: (ch.children || []).map((sub: any) => ({
          id: sub.id,
          title: sub.title,
          paragraphs: []
        })),
        paragraphs: [],
        docReference: Array.isArray(ch.docReference) ? ch.docReference : (ch.docReference ? parse2Json(ch.docReference) : []),
        chunkReference: Array.isArray(ch.chunkReference) ? ch.chunkReference : (ch.chunkReference ? parse2Json(ch.chunkReference) : [])
      }))
      totalDocObjects.value = newDocObjects

      if (newDocObjects.length > 0) currentChapterId.value = newDocObjects[0]?.id.toString()
      // 预取首章内容
      const blockId = mapped[0]?.blockId || ''
      if (mapped.length > 0 && blockId) {
        currentBlockId.value = String(blockId) // 保存 blockId
        const resDetail = await getDocumentBlockDetail(documentId, String(blockId))
        if (resDetail.code === 200 && resDetail.data) {
          currentBlockContent.value = resDetail.data.content || ''
        }
      }
    }
  } catch (e) {
    console.error('加载文档大纲失败:', e)
  }
}

// 切换引用资料折叠状态
const toggleReferenceMaterials = () => {
  isReferenceMaterialsExpanded.value = !isReferenceMaterialsExpanded.value
}

const docMetaData = ref([...mockDocMetaData])

// 文档mock数据
const totalDocObjects = ref([])

const recognitionResult = ref({ total: 0, applied: 0, pending: 0 })
const recognizedFields = ref<Record<string, { newValue: any, oldValue: any, section: string, status: string }>>({})
const showReviewDrawer = ref(false)

const fieldSectionMap: Record<string, string> = {
  landUseType: 'planning',
  seismicIntensity: 'planning',
  climateZone: 'planning',
  indoorOutdoorHeight: 'terrain',
  absoluteElevation: 'terrain',
  buildingType: 'function',
  buildingName: 'function',
  buildingFunction: 'function',
  buildingArea: 'function',
  plotRatioArea: 'function',
  floors: 'scale',
  buildingHeight: 'scale',
  structureType: 'scale',
  structureDesignLife: 'safety',
  fireResistanceGrade: 'fire',
  fireCategory: 'fire',
  waterproofCategory: 'waterproof',
  roofWaterproofLife: 'waterproof',
  waterproofGrade: 'waterproof',
  energyEfficiencyRequirement: 'energy',
  barrierFreeRequirement: 'barrier-free'
}


const sectionOrder = ['planning','terrain','function','scale','safety','fire','waterproof','energy','barrier-free']
const sectionTitle = (sec: string) => ({
  planning: '规划条件',
  terrain: '地形地貌',
  function: '使用功能',
  scale: '建筑规模与形态',
  safety: '安全等级',
  fire: '防火设计',
  waterproof: '防水设计',
  energy: '节能设计',
  'barrier-free': '无障碍设计'
}[sec] || sec)

const sectionCounts = computed(() => {
  const counts: Record<string, { recognized: number, total: number }> = {}
  Object.entries(fieldSectionMap).forEach(([key, sec]) => {
    counts[sec] = counts[sec] || { recognized: 0, total: 0 }
    counts[sec].total++
    const rf = recognizedFields.value[key]
    if (rf && rf.status !== 'rejected') counts[sec].recognized++
  })
  return counts
})

const uploadStatus = ref<'idle'|'uploading'|'success'|'error'>('idle')
const uploadedFileName = ref('')
const uploadedFileId = ref('')
const uploadProgress = ref(0)
const uploadStep = ref<'idle' | 'uploading' | 'parsing' | 'extracting'>('idle')
const uploadRef = ref<UploadInstance>()
const skipConfirmOverwrite = ref(false)

const uploadStepText = computed(() => {
    switch(uploadStep.value) {
        case 'uploading': return '上传中...'
        case 'parsing': return '智能解析中...'
        case 'extracting': return '识别提取中...'
        case 'idle': 
            if (uploadStatus.value === 'success') return '已上传'
            return ''
        default: return ''
    }
})

const beforeUpload = (file: File) => {
  const isImage = file.type.startsWith('image/')
  const isPdf = file.type === 'application/pdf'
  const isDocx = file.type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  // 部分浏览器可能无法准确识别 docx 的 MIME type，或者文件名后缀校验作为补充
  const fileName = file.name.toLowerCase()
  const isAllowedExt = fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.pdf') || fileName.endsWith('.docx')
  
  if (!isImage && !isPdf && !isDocx && !isAllowedExt) {
    ElMessage.error('仅支持图片(jpg/png)和文件(pdf/docx)格式')
    return false
  }
  
  // 校验文件大小: 图片 1MB, 文件 2MB
  const limit = isImage ? 1 : 2
  if (file.size / 1024 / 1024 > limit) {
    ElMessage.error(`${isImage ? '图片' : '文件'}大小不能超过 ${limit}MB`)
    return false
  }

  // 检查是否覆盖
  if (skipConfirmOverwrite.value) {
    skipConfirmOverwrite.value = false
    return true
  }

  if (uploadStatus.value === 'success') {
    return ElMessageBox.confirm(
      '新上传将覆盖原有的文件和识别结果，确认继续？',
      '提示',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    ).then(() => {
      // 确认覆盖
      return true
    }).catch(() => {
      // 取消
      return false
    })
  }
  
  return true
}

const handleExceed: UploadProps['onExceed'] = (files) => {
  ElMessageBox.confirm(
    '新上传将覆盖原有的文件和识别结果，确认继续？',
    '提示',
    {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    }
  ).then(() => {
    uploadRef.value!.clearFiles()
    const file = files[0] as UploadRawFile
    file.uid = genFileId()
    skipConfirmOverwrite.value = true
    uploadRef.value!.handleStart(file)
    uploadRef.value!.submit()
  }).catch(() => {
    // Cancelled
  })
}

const handleFileUpload = async (options: any) => {
  try {
    // recognizingProjectInfo.value = true // Uploading does not block recognition of other things, but here it's part of the flow
    uploadStatus.value = 'uploading'
    uploadStep.value = 'uploading'
    uploadProgress.value = 30 // Uploading started
    uploadedFileId.value = '' // Clear previous file ID
    
    const file = options.file as File
    uploadedFileName.value = file.name
    
    // 1. Upload only
    const uploadRes = await uploadFile(file, 'test_ygy')
    uploadProgress.value = 100
    uploadedFileId.value = uploadRes.data.id
    // const fileName = uploadRes.data.name
    
    // Clear previous recognition results
    recognitionResult.value = { total: 0, applied: 0, pending: 0 }
    recognizedFields.value = {}
    
    ElMessage.success('文件上传成功')
    uploadStatus.value = 'success'
    uploadStep.value = 'idle' // Reset step to idle, status shows 'success' -> "已上传，待识别"
    
    options.onSuccess && options.onSuccess(uploadRes.data)

  } catch (e: any) {
    ElMessage.error(e?.message || '上传失败')
    uploadStatus.value = 'error'
    options.onError && options.onError(e)
  } finally {
    // recognizingProjectInfo.value = false
    if(uploadStatus.value !== 'uploading' && uploadStatus.value !== 'success') {
       uploadStep.value = 'idle'
    }
  }
}

const removeUploadedFile = () => {
  uploadedFileName.value = ''
  uploadedFileId.value = ''
  uploadStatus.value = 'idle'
  uploadRef.value?.clearFiles()
}

const saveDocument = async () => {
  
  // 如果是服务器文档模式，保存 Markdown 内容
  if (isServerDoc.value && currentBlockContent.value) {
    await saveMarkdownContent(currentBlockContent.value)
    return
  }
  
  // TODO - 其他模式的保存逻辑
  setTimeout(() => {
    isModified.value = false
    showNotification('文档已保存', 'success')
  }, 500)
}

const exitDocument = () => {
  //TODO-根据修改状态，弹出确认提示
  ElMessageBox.confirm('确定要退出当前文档吗？', '提示', {
    // distinguishCancelAndClose: true,
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    // type: 'warning'
  }).then(async () => {
    if(isModified.value == true){
      await saveDocument()
    }
    handleExit()
  }).catch((action: Action) => {
    // if(action === 'close') {
    //   // 取消退出，不做任何操作
    // }else{
    //   handleExit()
    // }
  })
}

const handleExit = () => {
  // 确认退出，切换到欢迎页
  showWelcomePage.value = true
  hasActiveDocument.value = false
  showConfigPanel.value = false

  // 清空表单数据
  documentTitle.value = ''
  isModified.value = false

  // 重置项目表单
  projectForm.value = resetProjectForm()
  ElMessage.success('已退出文档编辑')
}

// 方法
const exportDocument = async (format: string, docId?: string) => {
  let message = ''
  
  // 确定要导出的文档ID
  const targetDocId = docId || currentDocumentId.value
  if (!targetDocId) {
    ElMessage.warning('请先选择要导出的文档')
    return
  }
  
  const targetDoc = documents.value.find(doc => doc.id === targetDocId)
  const docName = targetDoc?.name || '当前文档'
  
  switch(format) {
    case 'md':
      message = `正在导出"${docName}"为Markdown文件...`
      showNotification(message, 'info')
      
      try {
        const response = await exportDocumentMarkdown(targetDocId)
        
        if (response.code === 200 && response.data) {
          const { content, fileName } = response.data
          // 下载 Markdown 文件
          downloadFile(content, fileName, 'text/markdown')
          showNotification(`"${docName}"导出成功！`, 'success')
        } else {
          throw new Error(response.message || '导出失败')
        }
      } catch (error) {
        console.error('导出 Markdown 失败:', error)
        ElMessage.error(error instanceof Error ? error.message : '导出 Markdown 失败，请稍后重试')
      }
      break
    case 'cad':
      message = `正在将"${docName}"导入到AutoCAD...`
      showNotification(message, 'info')
      
      try {
        // 1. 获取 Markdown 内容
        const response = await exportDocumentMarkdown(targetDocId)
        
        if (response.code === 200 && response.data) {
          const { content } = response.data
          
          // 2. 发送到本地 AutoCAD 插件
          const cadResponse = await importToAutoCAD({
            markdown: content,
            template: {
              blockName: "A1_TemplateBlock",
              dwgUrl: "https://zspt-prod.oss-cn-guangzhou.aliyuncs.com/A1_TemplateBlock_dby.dwg"
            },
            options: {
              clearExisting: true
            }
          })
          
          if (cadResponse.success) {
            showNotification(`"${docName}"已发送至AutoCAD！`, 'success')
          } else {
            throw new Error(cadResponse.message || '导入AutoCAD失败')
          }
        } else {
          throw new Error(response.message || '获取文档内容失败')
        }
      } catch (error) {
        console.error('导入 AutoCAD 失败:', error)
        ElMessage.error(error instanceof Error ? error.message : '导入 AutoCAD 失败，请检查插件是否运行')
      }
      break
  }
}

const scrollToChapter = (chapterId: string) => {
  // 由于现在只显示单个章节，不需要滚动，但保留激活状态更新
  // const element = document.getElementById(`chapter-${chapterId}`)
  // if (element) {
  //   element.scrollIntoView({ behavior: 'smooth', block: 'start' })
  // }
  
  // 更新激活状态
  chapters.value.forEach(chapter => {
    chapter.active = chapter.id === chapterId
  })
}

// 通用的章节查找函数，支持递归查找子章节
const findChapterById = (chapters:any[], targetId:any):any => {
  for (const chapter of chapters) {
    if (chapter.id.toString() === targetId.toString()) {
      return chapter
    }
    if (chapter.children && chapter.children.length > 0) {
      const found = findChapterById(chapter.children, targetId)
      if (found) return found
    }
  }
  return null
}

// 计算属性：获取当前选中的章节数据
const currentChapter = computed(() => {
  // 如果没有选中章节且有可用章节，自动选中第一章
  if (!currentChapterId.value && totalDocObjects.value.length > 0) {
    currentChapterId.value = totalDocObjects.value[0]?.id?.toString() || ''
  }
  
  if (!currentChapterId.value) return null
  return findChapterById(totalDocObjects.value, currentChapterId.value)
})

const switchGenConfig = () => {
  showConfigPanel.value = !showConfigPanel.value
}

const handleContentStreaming = (content: string) => {
  // 实时更新编辑器内容（流式）
  currentBlockContent.value = content
}

const handleContentGenerated = (content: string) => {
  // 将 AI 生成的内容应用到当前章节的编辑器（生成完成）
  if (content && content.trim()) {
    currentBlockContent.value = content
    markAsModified()
    updateCurrentChapterSecondaryHeadings()
    ElMessage.success('AI 生成内容已应用到编辑器')
  }
}

const showNotification = (message: string, type: 'success' | 'info' | 'warning' | 'error' = 'info') => {
  ElNotification({
    title: '提示',
    message,
    type,
    duration: 3000
  })
}

const markAsModified = () => {
  isModified.value = true
  
  // 更新当前活动文档的修改时间
  const activeDoc = documents.value.find(doc => doc.isActive)
  if (activeDoc) {
    activeDoc.lastModified = new Date().toLocaleString('zh-CN')
  }
}

// 保存 Markdown 内容到后端
const saveMarkdownContent = async (content: string) => {
  if (!currentDocumentId.value || !currentBlockId.value) {
    ElMessage.warning('文档ID或块ID不存在，无法保存')
    return
  }
  
  try {
    // 只传递 content 参数，不传递 block_name
    const res = await updateDocumentBlock(
      currentDocumentId.value,
      currentBlockId.value,
      {
        block_name: currentChapter.value.title,
        content,
        docReference: currentChapter.value.docReference,
        chunkReference: currentChapter.value.chunkReference
      }
    )
    
    if (res.code === 200) {
      isModified.value = false
      showNotification('文档已保存', 'success')
    } else {
      ElMessage.error(res.message || '保存失败')
    }
  } catch (error) {
    console.error('保存 Markdown 内容失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  }
}

// 处理 Markdown 内容更新（用于实时标记为已修改）
const handleMarkdownUpdate = () => {
  markAsModified()
  // 更新当前章节的二级目录
  updateCurrentChapterSecondaryHeadings()
}

// 更新当前章节的二级目录（从 currentBlockContent 解析）
const updateCurrentChapterSecondaryHeadings = () => {
  if (!isServerDoc.value || !currentChapterId.value) return
  
  const chapter = chapters.value.find(ch => ch.id === currentChapterId.value)
  if (chapter && currentBlockContent.value) {
    // 传入当前章节ID以生成正确的序号（如 "1.1", "1.2"）
    const secondaryHeadings = parseSecondaryHeadings(currentBlockContent.value, currentChapterId.value)
    // 更新章节的 children
    if (secondaryHeadings.length > 0) {
      chapter.children = secondaryHeadings
    } else {
      chapter.children = undefined
    }

    // 同步：更新 totalDocObjects 中对应章节的 children
    const docObject = totalDocObjects.value.find(obj => obj.chapterId === `chapter-${currentChapterId.value}`)
    if (docObject) {
      docObject.children = secondaryHeadings.map((sub: any) => ({
        id: sub.id,
        title: sub.title,
        paragraphs: []
      }))
    }
  }
}

// 更新文档标题
const updateDocumentTitle = (newTitle: string) => {
  documentTitle.value = newTitle
  markAsModified()
}


// 文档管理方法
const createNewDocument = () => {
  startDocumentWizard()
}

// 智能识别功能
const recognizingProjectInfo = ref(false)
// 保存项目信息的定时器
const saveProjectInfoTimer = ref<ReturnType<typeof setTimeout> | null>(null)
const recognizeProjectInfo = async () => {
  const projectDescription = wizardForm.value.projectDescription?.trim() || ''
  const hasFile = !!uploadedFileId.value
  const prevForm = { ...wizardForm.value }
  
  if (!projectDescription && !hasFile) {
     ElMessage.warning('请先输入项目概况或文件')
     return
  }
  
  try {
    // Clear previous recognition results
    recognitionResult.value = { total: 0, applied: 0, pending: 0 }
    recognizedFields.value = {}

    recognizingProjectInfo.value = true
    ElMessage.info('正在识别项目概况信息...')
    
    let extractedData = null

    if (hasFile) {
        // File Flow
        uploadStatus.value = 'uploading' // Show processing state in UI (hides checkmark/delete)
        uploadStep.value = 'parsing'
        const parseRes = await parseFile(uploadedFileId.value, 'test_ygy')
        
        uploadStep.value = 'extracting'
    }
    
    // Unified Flow: Extract from both file (if exists) and text input
    console.log('ffffff fileId:',uploadedFileId.value)
    const extractRes = await extractKey(uploadedFileId.value || '', 'test_ygy', projectDescription)
    
    if (extractRes.data && extractRes.data.extracted) {
         extractedData = extractRes.data.extracted
    } else {
         throw new Error('识别未返回有效数据')
    }
    
    if (extractedData) {
      ElMessage.success('项目概况识别完成')
      
      const { mappedCount, mappedFields, mappedKeys } = processRecognitionResult(extractedData, wizardForm)
      if (mappedCount > 0) {
        const changedSections = new Set<string>()
        recognizedFields.value = {}
        
        // 使用返回的mappedKeys来更新识别结果，确保所有识别到的字段都被记录
        mappedKeys.forEach((key) => {
          const oldValue = (prevForm as any)[key]
          const newValue = (wizardForm.value as any)[key]
          
          const section = fieldSectionMap[key] || 'other'
          recognizedFields.value[key] = { newValue, oldValue, section, status: 'applied' }
          if (section !== 'other') changedSections.add(section)
        })

        recognitionResult.value = { total: Object.keys(recognizedFields.value).length, applied: Object.keys(recognizedFields.value).length, pending: 0 }
        ElMessage.success(`成功识别并填充了 ${mappedCount} 个字段：${mappedFields.join('、')}`)
      } else {
        recognitionResult.value = { total: 0, applied: 0, pending: 0 }
        ElMessage.warning('未能识别到可映射的字段信息')
      }
      
    } else {
      ElMessage.error('识别失败，未能获取有效信息')
    }
  } catch (error: any) {
    console.error('识别项目概况失败:', error)
    ElMessage.error(error.message || '识别失败，请检查网络连接')
    if (hasFile) {
        uploadStatus.value = 'error'
    }
  } finally {
    recognizingProjectInfo.value = false
    if (uploadStatus.value === 'uploading') {
        uploadStatus.value = 'success'
    }
    uploadStep.value = 'idle'
  }
}


const openReviewDrawer = () => {
  console.log('open review drawer')
  showReviewDrawer.value = true
}

const clearField = (key: string) => {
  // @ts-ignore
  wizardForm.value[key] = ''
  if (recognizedFields.value[key]) {
    recognizedFields.value[key].status = 'rejected'
  }
}

// 计算项目摘要
const projectSummary = computed(() => {
  const form = projectForm.value
  if (!form.projectName && !form.buildingArea && !form.buildingHeight) {
    return ''
  }
  
  const parts = []
  
  if (form.projectName) {
    parts.push(form.projectName)
  }
  
  if (form.buildingArea) {
    parts.push(`建筑面积${form.buildingArea}㎡`)
  }
  
  if (form.buildingHeight) {
    parts.push(`建筑高度${form.buildingHeight}m`)
  }
  
  if (form.floors) {
    const floorText = form.undergroundFloors 
      ? `地上${form.floors}层/地下${form.undergroundFloors}层`
      : `${form.floors}层`
    parts.push(floorText)
  }
  
  return parts.join(' | ')
})

// 保存项目信息到本地存储
const saveProjectInfo = () => {
  try {
    const projectData = {
      ...projectForm.value,
      lastUpdated: new Date().toISOString(),
      documentId: currentDocumentId.value || 'default'
    }
    
    // 保存到localStorage
    const storageKey = `project_info_${projectData.documentId}`
    localStorage.setItem(storageKey, JSON.stringify(projectData))
    
    console.log('项目信息已保存:', projectData)
  } catch (error) {
    console.error('保存项目信息失败:', error)
  }
}

// 从本地存储加载项目信息
const loadProjectInfo = (documentId: string) => {
  try {
    const storageKey = `project_info_${documentId}`
    const savedData = localStorage.getItem(storageKey)
    
    if (savedData) {
      const projectData = JSON.parse(savedData)
      // 更新表单数据
      Object.keys(projectForm.value).forEach(key => {
        if (projectData[key] !== undefined) {
          // @ts-ignore
          projectForm.value[key] = projectData[key]
        }
      })
      
      // 更新文档标签
      updateDocumentTags()
      console.log('项目信息已加载:', projectData)
      return true
    } 
  } catch (error) {
    console.error('加载项目信息失败:', error)
  }
  return false
}

// 更新文档标签
const updateDocumentTags = () => {
  const tags = generateDocumentTags(projectForm.value)
  docMetaData.value = tags
  console.log('文档标签已更新:', tags)
}

// 文档创建向导相关数据
const showDocumentWizard = ref(false)
const wizardStep = ref(1) // 1: 文档关键信息, 2:目录 大纲
const wizardSteps = ref([
  { id: 1, title: '关键信息', completed: false },
  { id: 2, title: '目录大纲', completed: false }
])

const outlineItems = ref([])
const autoGenerateOnCreate = ref(true)

// 向导相关方法
const startDocumentWizard = () => {
  showDocumentWizard.value = true
  wizardStep.value = 1
  wizardSteps.value.forEach((step: any) => step.completed = false)
  // 每次启动向导重置向导表单，避免遗留数据影响
  clearWizardProjectInfo()
  wizardForm.value = resetProjectForm()
  uploadStatus.value = 'idle'
}
// 向导内专用：清除项目信息（不影响现有文档）
const clearWizardProjectInfo = () => {
  Object.assign(wizardForm.value, resetProjectForm())
  recognitionResult.value = { total: 0, applied: 0, pending: 0 }
  recognizedFields.value = {}
  uploadedFileName.value = ''
  uploadStatus.value = 'idle'
}

const loadingNextStep = ref(false)
const nextWizardStep = async () => {
  // 检查项目名称是否为空
  const docName = wizardForm.value.projectName.trim()
  if (!docName) {
    ElMessage.warning('请输入文档名称')
    return
  }

  const abs_test = wizardForm.value.projectDescription?.trim();
  const hasFile = uploadStatus.value === 'success';
  if(!abs_test && !hasFile){
    ElMessage.warning('未输入项目概况。请输入内容或上传文件')
    return
  }

  loadingNextStep.value = true
  try {
    // 如果是第一步到第二步，调用RAGFlow接口生成大纲
    if (wizardStep.value === 1) {
      // 延时1秒，模拟AI生成
      await new Promise(resolve => setTimeout(resolve, 1000))
      const outLines = outlineTemplate.map(item => ({
        id: item.id,
        title: item.title,
        order: item.order ?? item.id,
        children: (item.children || []).map(child => ({
          id: child.id,
          title: child.title,
          order: child.order ?? child.id,
        })),
        expanded: item.expanded ?? ((item.children || []).length > 0)
      }))
      outlineItems.value = outLines
      ElMessage.success('大纲生成成功')
    }
    loadingNextStep.value = false
    
    // 继续原有的步骤逻辑
    if (wizardStep.value < wizardSteps.value.length) {
      const currentStep = wizardSteps.value[wizardStep.value - 1]
      if (currentStep) {
        currentStep.completed = true
      }
      wizardStep.value++
    }
  } catch (error) {
    console.error('生成大纲时发生错误:', error)
    ElMessage.error('生成大纲时发生错误')
  } finally {
    loadingNextStep.value = false
  }
}

const prevWizardStep = () => {
  if (wizardStep.value > 1) {
    wizardStep.value--
    const currentStep = wizardSteps.value[wizardStep.value - 1]
    if (currentStep) {
      currentStep.completed = false
    }
  }
}

const removeOutlineItem = (id: number) => {
  const index = outlineItems.value.findIndex(item => item.id === id)
  if (index > -1) {
    outlineItems.value.splice(index, 1)
    // 重新排序
    outlineItems.value.forEach((item, index) => {
      item.order = index + 1
    })
  }
}

const updateOutlineTitle = (id: number, title: string) => {
  const item = outlineItems.value.find(item => item.id === id)
  if (item && title) {
    item.title = title
  }
}

// 拖拽相关方法
let draggedIndex: number | null = null

const handleDragStart = (event: DragEvent, index: number) => {
  draggedIndex = index
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
  }
}

const handleDragOver = (event: DragEvent) => {
  event.preventDefault()
  if (event.dataTransfer) {
    event.dataTransfer.dropEffect = 'move'
  }
}

const handleDrop = (event: DragEvent, dropIndex: number) => {
  event.preventDefault()
  if (draggedIndex !== null && draggedIndex !== dropIndex) {
    const draggedItem = outlineItems.value[draggedIndex]
    if (draggedItem) {
      outlineItems.value.splice(draggedIndex, 1)
      outlineItems.value.splice(dropIndex, 0, draggedItem)
      
      // 重新排序
      outlineItems.value.forEach((item, index) => {
        item.order = index + 1
      })
    }
  }
  draggedIndex = null
}

// 在指定位置后添加大纲项
const addOutlineItemAfter = (index: number) => {
  const newId = Math.max(...outlineItems.value.map(item => item.id)) + 1
  const newItem = {
    id: newId,
    title: '新章节',
    order: index + 2,
    children: [],
    expanded: false
  }
  outlineItems.value.splice(index + 1, 0, newItem)
  
  // 重新排序
  outlineItems.value.forEach((item, index) => {
    item.order = index + 1
  })
}

// 切换大纲项展开/收起状态
const toggleOutlineExpand = (id: number) => {
  const item = outlineItems.value.find(item => item.id === id)
  if (item) {
    item.expanded = !item.expanded
  }
}

// 子节点拖拽相关变量
let draggedSubInfo: { parentIndex: number, subIndex: number } | null = null

// 子节点拖拽开始
const handleSubDragStart = (event: DragEvent, parentIndex: number, subIndex: number) => {
  draggedSubInfo = { parentIndex, subIndex }
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
  }
}

// 子节点拖拽放置
const handleSubDrop = (event: DragEvent, dropParentIndex: number, dropSubIndex: number) => {
  event.preventDefault()
  if (draggedSubInfo && 
      (draggedSubInfo.parentIndex !== dropParentIndex || draggedSubInfo.subIndex !== dropSubIndex)) {
    
    const sourceParent = outlineItems.value[draggedSubInfo.parentIndex]
    const targetParent = outlineItems.value[dropParentIndex]
    
    if (sourceParent?.children && targetParent?.children) {
      const draggedItem = sourceParent.children[draggedSubInfo.subIndex]
      
      // 从源位置移除
      sourceParent.children.splice(draggedSubInfo.subIndex, 1)
      
      // 插入到目标位置
      targetParent.children.splice(dropSubIndex, 0, draggedItem!)
    }
  }
  draggedSubInfo = null
}

// 在指定位置后添加子大纲项
const addSubOutlineItemAfter = (parentIndex: number, subIndex: number) => {
  const parentItem = outlineItems.value[parentIndex]
  if (parentItem) {
    if (!parentItem.children) {
      parentItem.children = []
    }
    
    // 生成新的子节点ID
    const allSubIds = outlineItems.value.flatMap(item => 
      item.children?.map(child => child.id) || []
    )
    const newSubId = allSubIds.length > 0 ? Math.max(...allSubIds) + 1 : 1001
    
    const newSubItem = {
      id: newSubId,
      title: '新子章节',
      order: subIndex + 2
    }
    
    parentItem.children.splice(subIndex + 1, 0, newSubItem)
    parentItem.expanded = true // 自动展开父节点
    
    // 重新排序子节点
    parentItem.children.forEach((child, index) => {
      child.order = index + 1
    })
  }
}

// 更新子大纲项标题
const updateSubOutlineTitle = (parentId: number, subId: number, title: string) => {
  const parentItem = outlineItems.value.find(item => item.id === parentId)
  if (parentItem?.children) {
    const subItem = parentItem.children.find(child => child.id === subId)
    if (subItem && title) {
      subItem.title = title
    }
  }
}

// 删除子大纲项
const removeSubOutlineItem = (parentId: number, subId: number) => {
  const parentItem = outlineItems.value.find(item => item.id === parentId)
  if (parentItem?.children) {
    const subIndex = parentItem.children.findIndex(child => child.id === subId)
    if (subIndex > -1) {
      parentItem.children.splice(subIndex, 1)
      
      // 重新排序剩余子节点
      parentItem.children.forEach((child, index) => {
        child.order = index + 1
      })
    }
  }
}

const loadingDocGenarate = ref(false) 
//文档创建-不生成全部章节
const finishDocumentWizard = async() => {
  const finalDocumentName = createDocumentName(wizardForm.value.projectName)
  
  if(docNameOrUserInvalid(finalDocumentName)) return
  loadingDocGenarate.value = true
  let createdDocId = await execCreateDocument(finalDocumentName)

  // 根据目录大纲批量创建文档块
  if (createdDocId) {
    // 创建成功后，拉取最新大纲用于展示
    currentDocumentId.value = createdDocId
    try {
      const blocks = createBlocksByDefault()
      const batchRes = await batchCreateDocumentBlocks(createdDocId, {
        level: 1,
        parent_id: null,
        blocks,
        returnOnlyIds: true
      })
      // 更新当前章节数据
      await loadDocumentOutline(createdDocId)
      if (!(batchRes.code === 201 || batchRes.code === 200)) {
        ElMessage.warning(batchRes.message || '批量创建文档块失败')
        return false;
      }
    } catch (e) {
      loadingDocGenarate.value = false
      console.error('批量创建文档块异常:', e)
      ElMessage.warning('批量创建文档块失败，请稍后在编辑页重试')
      return false;
    }
  }
  
  // 将所有现有文档设置为非激活状态
  documents.value.forEach(doc => {
    doc.isActive = false
  })
  const newDoc = updateDocumentList(createdDocId, finalDocumentName)
  saveProjectData(finalDocumentName)
  
  
  // 更新文档标题
  documentTitle.value = finalDocumentName
  
  // 隐藏欢迎页，显示文档编辑界面
  showWelcomePage.value = false
  hasActiveDocument.value = true
  
  // 关闭向导，仅重置向导表单
  wizardForm.value = resetProjectForm()
  loadingDocGenarate.value = false
  showDocumentWizard.value = false
  showConfigPanel.value = true
  ElMessage.success(`文档"${finalDocumentName}"创建成功`)

  // 立即更新新文档标签（基于向导表单）
  docMetaData.value = generateDocumentTags(newDoc.projectInfo || {})
  
  // 刷新文档列表
  await loadDocumentList()
  return {docId: createdDocId, docName: finalDocumentName};
}

const chapterGenerationStatus = ref<Record<string, { status: 'pending' | 'generating' | 'done' | 'error'; progress: number; message?: string; updatedAt?: number }>>({})
const MAX_CONCURRENCY = 5
const runWithConcurrency = async <T, R>(
  items: T[],
  worker: (item: T, index: number) => Promise<R>,
  limit: number
): Promise<R[]> => {
  const results: R[] = new Array(items.length)
  let nextIndex = 0
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const idx = nextIndex++
      if (idx >= items.length) break
      results[idx] = await worker(items[idx], idx)
    }
  })
  await Promise.all(workers)
  return results
}


const extractGeneratedContent = (resp: any) => {
  if (!resp) return ''
  const d = resp.data
  if (typeof d === 'string') return d
  if (d && typeof d === 'object') {
    if (typeof d.text === 'string') return d.text
    if (typeof d.content === 'string') return d.content
  }
  if (Array.isArray(d)) {
    return d.map((it: any) => (typeof it === 'string' ? it : (it?.content || it?.text || ''))).join('\n')
  }
  return ''
}

//文档创建-批量生成全部章节
const generateDocumentDefault = async(forTest:boolean=false) => {
  let res = await finishDocumentWizard();
  // console.log('rrrrrrrrrrrr res:',res)

  if (res) {
    const {docId, docName} = res

    const allItems = (chapters.value && chapters.value.length > 0) ? chapters.value : outlineItems.value
    const indices = Array.from({ length: allItems.length }, (_, i) => i)
    // const indices = Array.from({ length: 3 }, (_, i) => i)
    await runWithConcurrency(indices, async (index) => {
      const idx = index as number
      const item: any = allItems[idx]
      const chapterId = String(item.id || idx + 1)
      chapterGenerationStatus.value[chapterId] = { status: 'generating', progress: 0, updatedAt: Date.now() }
      
      const titleStr = String(item.title || '').trim()
      const chapterName = `${chapterId}.${titleStr}`
      
      //TODO- query需要补充上当前章节的二级标题内容
      const titles = (item?.children || []).map((sub: any) => String(sub.title || '').trim()).filter((t: string) => !!t)
      const query = titles.length > 0 ? `生成章节，包括 ${titles.join(';\n')}.` : '生成章节。'
      const docObject = totalDocObjects.value.find((o: any) => String(o.title || '') === titleStr)
      if (docObject) {
        docObject.loading = true
      }

      try {
        const promptParams: any = (promptParamsByTitle as any)[titleStr] || {} 
        const usePromptParams = !!(promptParams && (promptParams.structure || promptParams.feature || promptParams.requirement))

        const params = {
          query,
          title: documentTitle.value,
          requirement: '',
          structure: '',
          feature: '',
          chapterName,
          addition: '',
          template: '',
          usePromptParams,
          document_id: currentDocumentId.value,  // 传递 document_id 用于 Langfuse session 关联
          user_id: userId.value,                 // 传递 user_id
        }

        if (usePromptParams) {
          params.structure = String(promptParams.structure || '')
          params.feature = String(promptParams.feature || '')
          params.requirement = String(promptParams.requirement || '')
        }

        const resp = await generateParagraphBatch(params)
        const content = extractGeneratedContent(resp)
        const docRefRaw = resp?.data?.doc_reference || null
        const chkRefRaw = resp?.data?.chunk_reference || null

        //当前章节的内容，需要立即更新到编辑器
        if (String(item?.id) === String(currentChapterId.value)) {
          currentBlockContent.value = content || ''
          updateCurrentChapterSecondaryHeadings()
        }
        if (docObject) {
          docObject.docReference = docRefRaw || []
          docObject.chunkReference = chkRefRaw || []
        }

        const blockName = String(item.title || '').trim()
        const targetChapter = chapters.value.find((ch: any) => String(ch.id) === chapterId)
        // console.log('tttttttt template res + target chapter:',resp,targetChapter)
        if (targetChapter && targetChapter.blockId) {
          await updateDocumentBlock(
            docId,
            String(targetChapter.blockId),
            {
              block_name: blockName,
              content,
              docReference: docRefRaw || [],
              chunkReference: chkRefRaw || []
            }
          )
          // console.log('dddddddddddddddddddd doc obj+ref+chunk:',docRefRaw, chkRefRaw, chapters.value)
        }
        chapterGenerationStatus.value[chapterId] = { status: 'done', progress: 100, updatedAt: Date.now() }
        return { block_name: blockName, content }
      } catch (e: any) {
        const obj = totalDocObjects.value.find((o: any) => String(o.title || '') === String(item.title || '').trim())
        if (obj) {
          obj.loading = false
        }
        chapterGenerationStatus.value[chapterId] = { status: 'error', progress: 0, message: String(e?.message || ''), updatedAt: Date.now() }
        return { block_name: String(item.title || '').trim(), content: '' }
      }
    }, MAX_CONCURRENCY)

    chapterGenerationStatus.value = {}
  }
}

const docNameOrUserInvalid = (docName:string) => {
  // 检查文档名称是否已存在
  const existingDoc = documents.value.find(doc => doc.name === docName)
  if (existingDoc) {
    ElMessage.warning('文档名称已存在，请修改项目名称')
    return true
  }
  if (!userId.value) {
    ElMessage.error('请先登录')
    return true
  }
  return false
}

const updateDocumentList = (docId:string, docName:string) => {
  documents.value.forEach(doc => { doc.isActive = false })
  const newDoc: DocumentItem = {
    id: docId || Date.now().toString(),
    name: docName,
    lastModified: new Date().toLocaleString('zh-CN'),
    status: 'draft',
    isActive: true, // 新创建的文档应该被选中
    projectInfo: { ...wizardForm.value },
    outline: [...outlineItems.value]   // 保存大纲到文档对象中
  }

  // 将新文档添加到数组开头，确保最新文档在最上面
  documents.value.unshift(newDoc)
  return newDoc;
}

const formatSecondaryHeadingLine = (chapterIdx: number, sectionIdx: number, title: string) => {
  return `## ${chapterIdx}.${sectionIdx} ${title}`
}

const createBlocksByDefault = () => {
  const blocks = outlineItems.value.map((item: any, idx: number) => {
    // 生成二级大纲的 content
    let content = ''
    if (item.children && Array.isArray(item.children) && item.children.length > 0) {
      const contentParts = item.children.map((child: any, cIdx: number) => {
        const title = child.title || ''
        const childContent = child.content || ''
        const heading = formatSecondaryHeadingLine(idx + 1, cIdx + 1, title)
        if (childContent) {
          return `${heading}\n${childContent.trim()}`
        } else {
          return heading
        }
      })
      // 每个二级大纲之间用 \n\n 分隔
      content = contentParts.join('\n\n')
    }

    // 将“项目概况”写入到第二个节点（工程概况）块的内容中
    const overview = (wizardForm.value.projectDescription || '').trim()
    const isOverviewChapter = idx === 1 || String(item.title || '').trim() === '工程概况'
    if (overview && isOverviewChapter) {
      content = overview
    }
    
    return {
      block_name: String(item.title || '').trim(),
      block_type: 'heading_1' as const,
      content
    }
  })
  return blocks;
}

const saveProjectData = (docName:string) => {
  //保存项目数据到localStorage，包含大纲信息
  const projectData = {
    title: docName,
    projectInfo: { ...wizardForm.value },
    outline: [...outlineItems.value] // 保存修改后的大纲
  }
  localStorage.setItem('currentProject', JSON.stringify(projectData))
}

// 生成文档名称，格式：项目名称 日期（如：项目名称 20240820）
const createDocumentName = (name:string) => {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const currentDate = `${year}${month}${day}`
  return `${name} ${currentDate}`
}

const execCreateDocument = async (docName:string) => {
  let docId = '';
   try {
    const result = await createDocument({
      name: docName,
      userId: userId.value,
      projectInfo: { ...wizardForm.value }
    })
    if (result.code === 201 || result.code === 200) {
      docId = result.data?.id || ''
    } else {
      ElMessage.error(result.message || '创建文档失败')
      loadingDocGenarate.value = false
      return ''
    }
  } catch (e) {
    console.error('创建文档接口异常:', e)
    ElMessage.error('创建文档失败，请稍后重试')
    loadingDocGenarate.value = false
    return ''
  }
  return docId;
}

const switchDocument = async (docId: string) => {
  // 更新所有文档的激活状态
  documents.value.forEach(doc => {
    doc.isActive = doc.id === docId
  })
  
  // 隐藏欢迎页，显示文档编辑界面
  showWelcomePage.value = false
  hasActiveDocument.value = true
  showConfigPanel.value = true
  // isOutlineCollapsed.value = false
  
  // 更新当前文档标题
  const activeDoc = documents.value.find(doc => doc.id === docId)
  if (activeDoc) {
    documentTitle.value = activeDoc.name
    // 从后端获取该文档的大纲
    currentDocumentId.value = docId
    await loadDocumentOutline(docId)
    
    // 重新排序，确保最新访问的文档在最上面
    sortDocumentsByDate()
  }
  
  ElMessage.success(`已切换到文档：${activeDoc?.name}`)
}

const renameDocument = (docId: string) => {
  const doc = documents.value.find(d => d.id === docId)
  if (doc) {
    editingDocumentId.value = docId
    editingDocumentName.value = doc.name
    showRenameDialog.value = true
  }
}

const confirmRename = async () => {
  if (!editingDocumentName.value.trim()) {
    ElMessage.warning('请输入文档名称')
    return
  }
  
  const doc = documents.value.find(d => d.id === editingDocumentId.value)
  if (!doc) {
    ElMessage.error('文档不存在')
    return
  }

  const newName = editingDocumentName.value.trim()
  
  try {
    const result = await renameDocumentApi(editingDocumentId.value, newName)
    
    if (result.code === 200) {
      // 更新本地数据
      doc.name = newName
      doc.lastModified = new Date().toLocaleString('zh-CN')
      
      // 如果是当前激活的文档，更新标题
      if (doc.isActive) {
        documentTitle.value = doc.name
      }
      
      // 重新排序
      sortDocumentsByDate()
      
      showRenameDialog.value = false
      ElMessage.success(result.message || '文档重命名成功')
      
      // 刷新文档列表
      await loadDocumentList()
    } else {
      ElMessage.error(result.message || '文档重命名失败')
    }
  } catch (error) {
    console.error('重命名文档失败:', error)
    ElMessage.error('文档重命名失败，请稍后重试')
  }
}

const deleteDocument = async (docId: string) => {
  const doc = documents.value.find(d => d.id === docId)
  if (!doc) return
  
  try {
    await ElMessageBox.confirm(
      `确定要删除文档"${doc.name}"吗？此操作不可恢复。`,
      '确认删除',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )
    
    // 调用删除接口
    const result = await deleteDocumentApi(docId)
    
    if (result.code === 200) {
      // 如果删除的是当前激活的文档，切换到欢迎页
      if (doc.isActive) {
        showWelcomePage.value = true
        hasActiveDocument.value = false
        showConfigPanel.value = false
        // 清除当前文档相关数据
        documentTitle.value = ''
        isModified.value = false
        chapters.value = []
        // documentObjects.value = []
        projectForm.value = resetProjectForm()
      }
      
      documents.value = documents.value.filter(d => d.id !== docId)
      ElMessage.success(result.message || '文档删除成功')
      
      // 刷新文档列表（虽然已经删除了本地数据，但为了保持一致性）
      await loadDocumentList()
    } else {
      ElMessage.error(result.message || '文档删除失败')
    }
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除文档失败:', error)
      ElMessage.error('文档删除失败，请稍后重试')
    }
    // 用户取消删除，不做任何操作
  }
}


const handleDocumentAction = (command: string, docId: string) => {
  switch (command) {
    case 'rename':
      renameDocument(docId)
      break
    case 'delete':
      deleteDocument(docId)
      break
    case 'export_md':
      exportDocument('md', docId)
      break
  }
}

// 加载文档列表
const loadDocumentList = async () => {
  // 检查用户ID
  if (!userId.value) {
    console.warn('用户ID不存在，无法加载文档列表')
    loadingDocuments.value = false
    return
  }

  loadingDocuments.value = true
  try {
    const result = await getDocumentList({
      page: 1,
      pageSize: 20,
      userId: userId.value
    })
    
    if (result.code === 200 && result.data) {
      // 将后端返回的数据格式转换为前端需要的 DocumentItem 格式
      const convertedDocuments: DocumentItem[] = result.data.list.map((doc) => {
        // 解析 projectInfo（后端返回的是 JSON 字符串）
        let projectInfo: ProjectInfo | undefined
        try {
          const projectInfoStr = doc.projectInfo
          let tempInfo: any
          
          if (typeof projectInfoStr === 'string') {
            const parsed = JSON.parse(projectInfoStr)
            // 如果解析后还是嵌套的对象，需要再次解析
            tempInfo = typeof parsed === 'string' ? JSON.parse(parsed) : parsed
          } else {
            tempInfo = projectInfoStr
          }

          // 处理可能的嵌套结构 { projectInfo: { ... } }
          if (tempInfo && typeof tempInfo === 'object' && tempInfo.projectInfo) {
            projectInfo = tempInfo.projectInfo
          } else {
            projectInfo = tempInfo
          }
        } catch (e) {
          console.warn('解析 projectInfo 失败:', e)
          projectInfo = undefined
        }
        
        // 格式化最后修改时间
        const lastModified = doc.updatedAt 
          ? new Date(doc.updatedAt).toLocaleString('zh-CN', {
              year: 'numeric',
              month: '2-digit',
              day: '2-digit',
              hour: '2-digit',
              minute: '2-digit',
              second: '2-digit',
              hour12: false
            }).replace(/\//g, '-')
          : new Date().toLocaleString('zh-CN')
        
        return {
          id: doc.id,
          name: doc.name,
          lastModified: lastModified,
          status: doc.isDeleted ? 'draft' : 'draft' as const, // 根据实际情况设置状态
          isActive: false, // 初始状态都不激活
          projectInfo: projectInfo,
          outline: undefined // 大纲数据需要单独获取
        }
      })
      
      documents.value = convertedDocuments
      // 按最后修改时间排序
      sortDocumentsByDate()
    } else {
      ElMessage.error(result.message || '加载文档列表失败')
      // 如果加载失败，使用 mock 数据作为降级方案
    }
  } catch (error) {
    console.error('加载文档列表失败:', error)
    ElMessage.error('加载文档列表失败，请稍后重试')
    // 如果加载失败，使用 mock 数据作为降级方案
  } finally {
    loadingDocuments.value = false
  }
}

// 生命周期
onMounted(async () => {
  // 加载文档列表
  await loadDocumentList()
  
  // 初始化文档排序
  sortDocumentsByDate()
  
  // 检查是否有活动文档
  const hasActive = documents.value.some(doc => doc.isActive)
  
  // 加载项目数据
  const projectId = route.params.id
  if (projectId) {
    currentDocumentId.value = projectId as string
    const projectData = localStorage.getItem('currentProject')
    if (projectData) {
      const project = JSON.parse(projectData)
      // 使用向导页面生成的标题
      documentTitle.value = project.title || '施工设计说明'
      
      // 隐藏欢迎页，显示文档编辑界面
      showWelcomePage.value = false
      hasActiveDocument.value = true
      
      // 加载项目信息
      loadProjectInfo(currentDocumentId.value)
      
      // 如果有向导生成的大纲，更新章节数据
      if (project.outline && project.outline.length > 0) {
        // 根据向导生成的大纲更新章节
        const newChapters = project.outline.map((item: any, index: number) => ({
          id: item.id,
          title: item.title,
          active: index === 0
        }))
        chapters.value = newChapters
        
        // 设置默认选中第一个章节
        if (newChapters.length > 0) {
          currentChapterId.value = newChapters[0].id
        }
        
        // 更新文档对象数据
        const newDocObjects = project.outline.map((item: any, index: number) => ({
          id: index + 1,
          chapterId: `chapter-${item.id}`,
          type: 'chapter',
          title: item.title,
          hasContent: false,
          loading: false,
          actions: ['generate'],
          children: [],
          paragraphs: []
        }))
        totalDocObjects.value = newDocObjects
      }
    }
  } else if (hasActive) {
    // 如果有活动文档但没有项目ID，隐藏欢迎页
    showWelcomePage.value = false
    hasActiveDocument.value = true
    
    // 尝试加载默认项目信息
    loadProjectInfo(currentDocumentId.value)
    
    // 设置默认选中第一个章节
    if (totalDocObjects.value.length > 0) {
      currentChapterId.value = totalDocObjects.value[0]?.id.toString() || ''
    }
  } else {
    // 没有活动文档，显示欢迎页
    showWelcomePage.value = true
    hasActiveDocument.value = false
    
    // 尝试加载默认项目信息
    loadProjectInfo(currentDocumentId.value)
    documentTitle.value = ''
  } 
  
  // 设置自动保存
  setInterval(() => {
    if (isModified.value) {
      console.log('自动保存...')
      isModified.value = false
    }
  }, 30000)
})

// 监听项目表单变化，自动保存
watch(projectForm, (newValue, oldValue) => {
  // 防抖处理，避免频繁保存
  if (saveProjectInfoTimer.value) {
    clearTimeout(saveProjectInfoTimer.value)
  }
  
  saveProjectInfoTimer.value = setTimeout(() => {
    saveProjectInfo()
    // updateDocumentTags()
  }, 1000) // 1秒后保存
}, { deep: true })

</script>

<template>
  <div class="editor-page">
    <!-- 顶部导航栏 -->
    <header class="header">
      <div class="header-content">
        <div class="header-left">
          <HeaderLogo />
          <nav class="nav-menu">
            <!-- <router-link class="nav-item active" to="/editor">文档生成</router-link>
            <router-link class="nav-item" to="/qa">项目问答</router-link> -->
          </nav>
        </div>
        <div class="user-info">
          <el-tooltip
            v-if="!showWelcomePage && hasActiveDocument"
            content="AI 智能助手"
            placement="bottom"
            :show-after="300"
          >
            <el-button
              :type="showConfigPanel ? 'primary' : 'default'"
              circle
              @click="switchGenConfig"
            >
              <el-icon><MagicStick /></el-icon>
            </el-button>
          </el-tooltip>

          <el-dropdown trigger="click" @command="handleUserCommand">
            <div class="user-avatar">
              {{ userInfo?.nickname?.charAt(0) || userInfo?.name?.charAt(0) || '设' }}
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item disabled>
                  <div class="user-dropdown-info">
                    <div class="user-dropdown-name">{{ userInfo?.nickname || userInfo?.name || '用户' }}</div>
                    <div class="user-dropdown-email">{{ userInfo?.email || '' }}</div>
                  </div>
                </el-dropdown-item>
                <el-dropdown-item divided command="settings" :icon="Setting">
                  模板管理
                </el-dropdown-item>
                <el-dropdown-item command="logout" :icon="SwitchButton">
                  退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>
    </header>

    <!-- 编辑器主体 -->
    <div class="editor-container" :style="editorContainerStyle" :class="{
      'with-config-panel': showConfigPanel,
      'welcome-mode': showWelcomePage,
      'outline-collapsed': isOutlineCollapsed && !showWelcomePage && hasActiveDocument,
      'resizing': isResizingChat
    }">
      <!-- 左侧文档管理栏 -->
      <DocumentList 
        :documents="documents"
        @createNewDocument="createNewDocument"
        @switchDocument="switchDocument"
        @exportDocument="exportDocument"
        @handleDocumentAction="handleDocumentAction"
      />

      <!-- 中间章节导航 - 只在有活动文档时显示 -->
      <DocumentOutline 
        v-show="!showWelcomePage && hasActiveDocument"
        :chapters="chapters"
        :chapterStatus="chapterGenerationStatus"
        @chapter-click="handleChapterClick"
        @chapter-collapse="handleChapterCollapse"
        @outline-toggle="handleOutlineToggle"
      />

      <!-- 中间编辑区 -->
      <main class="editor-main">
        <!-- 欢迎页 -->
        <div v-if="showWelcomePage" class="welcome-page">
          <div class="welcome-content">
            <div class="welcome-header">
              <div class="welcome-icon">📝</div>
              <h1 class="welcome-title">AIAD 智绘设计</h1>
              <p class="welcome-subtitle">AI驱动 + 知识库辅助，3分钟完成专业设计文档</p>
            </div>
            
            <div class="welcome-actions">
              <el-button type="primary" size="large" @click="createNewDocument" class="welcome-cta-button">
                <el-icon><Plus/></el-icon>
                新建文档
              </el-button>
            </div>
            
            <div class="welcome-stats">
              <div class="stat-item">
                <div class="stat-number">1,247</div>
                <div class="stat-label">已生成文档</div>
              </div>
              <div class="stat-item">
                <div class="stat-number">89%</div>
                <div class="stat-label">效率提升</div>
              </div>
              <div class="stat-item">
                <div class="stat-number">500+</div>
                <div class="stat-label">规范条文</div>
              </div>
            </div>
            
            <div class="welcome-features">
              <h3 class="features-title">核心功能</h3>
              <div class="features-grid">
                <div class="feature-card">
                  <div class="feature-icon">🤖</div>
                  <h4 class="feature-title">AI 智能生成</h4>
                  <p class="feature-desc">输入项目基本信息，AI自动生成符合规范的设计说明初稿</p>
                </div>
                <div class="feature-card">
                  <div class="feature-icon">✍️</div>
                  <h4 class="feature-title">可视化编辑</h4>
                  <p class="feature-desc">Markdown编辑器，章节化管理，所见即所得</p>
                </div>
                <div class="feature-card">
                  <div class="feature-icon">📚</div>
                  <h4 class="feature-title">知识库检索</h4>
                  <p class="feature-desc">集成500+规范条文，一键插入标准表述</p>
                </div>
                <div class="feature-card">
                  <div class="feature-icon">💬</div>
                  <h4 class="feature-title">AI 助手</h4>
                  <p class="feature-desc">续写、改写、优化，智能辅助编辑全流程</p>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- 文档编辑界面 -->
        <div v-else class="document-editor">
          <div class="document-header">
              <div class="document-header-content">
                <div 
                  class="document-title"
                  contenteditable="true"
                  @blur="updateDocumentTitle(($event.target as HTMLElement).textContent || '')"
                  @keydown.enter.prevent="($event.target as HTMLElement).blur()"
                >
                    {{ documentTitle }}
                </div>
                <!-- 项目信息摘要 -->
                <div v-if="projectSummary" class="project-summary">
                  <el-tag size="small" type="info">{{ projectSummary }}</el-tag>
                </div>
                <div class="document-meta">
                  <el-tag v-for="meta in docMetaData" :key="meta.name" :type="meta.type">{{ meta.name }}</el-tag>
                  <!-- <el-button 
                    size="small" 
                    type="default" 
                    class="doc-op-btn meta-view-btn" 
                    @click="openReviewDrawer"
                  >...</el-button> -->
                </div>
              </div>
              <div class="document-operations">
                <el-button 
                  size="small" 
                  type="default" 
                  :icon="Document" 
                  class="doc-op-btn doc-op-save" 
                  @click="saveDocument"
                >保存</el-button>
                <el-button 
                  size="small" 
                  type="default" 
                  :icon="Close" 
                  class="doc-op-btn doc-op-exit" 
                  @click="exitDocument"
                >退出</el-button>
              </div>
          </div>

          <div class="editor-content">
           <!-- 后端模式：Markdown 编辑区域 -->
           <section v-if="isServerDoc" class="chapter-section markdown-section">
           <MarkdownEditor
              v-model="currentBlockContent"
              :in-generating="inGenerating"
              :current-chapter="currentChapter"
              @update:modelValue="handleMarkdownUpdate"
              @blur="handleMarkdownUpdate"
              @save="saveMarkdownContent"
            />
           </section>
          </div>
          
          <!-- 引用资料 & 操作记录 - 合并底部区域 -->
          <div class="reference-materials-bottom">
            <div class="reference-header" @click="toggleReferenceMaterials">
              <h3 class="reference-title">
                <el-icon class="reference-icon" :class="{ 'expanded': isReferenceMaterialsExpanded }">
                  <ArrowRight />
                </el-icon>
                <!-- 收起时只显示当前激活的tab名称 -->
                <span v-if="!isReferenceMaterialsExpanded" class="collapsed-title">
                  {{ activeBottomTab === 'reference' ? '引用资料' : '操作记录' }}
                </span>
                <!-- 展开时显示tabs -->
                <div v-else class="bottom-tabs">
                  <span
                    class="bottom-tab"
                    :class="{ 'active': activeBottomTab === 'reference' }"
                    @click.stop="activeBottomTab = 'reference'"
                  >引用资料</span>
                  <span
                    class="bottom-tab"
                    :class="{ 'active': activeBottomTab === 'operation' }"
                    @click.stop="activeBottomTab = 'operation'"
                  >操作记录</span>
                </div>
              </h3>
              <el-icon class="toggle-icon" :class="{ 'expanded': isReferenceMaterialsExpanded }">
                <ArrowRight />
              </el-icon>
            </div>

            <el-collapse-transition>
              <div v-show="isReferenceMaterialsExpanded" class="reference-content-wrapper">
                <div class="reference-content">
                  <!-- 引用资料 tab -->
                  <template v-if="activeBottomTab === 'reference'">
                    <div
                      v-if="!(currentChapter && currentChapter.docReference?.length)"
                      class="reference-empty"
                    >
                      <el-icon class="empty-icon"><Document /></el-icon>
                      <span class="empty-text">暂无引用资料</span>
                    </div>
                    <div
                      v-if="currentChapter && currentChapter.docReference && currentChapter.docReference.length"
                      class="reference-items"
                    >
                      <div
                        class="reference-item"
                        v-for="(refItem, index) in currentChapter.docReference"
                        :key="refItem.id || index"
                      >
                        <div class="item-header">
                          <span class="item-title">{{ refItem.name || refItem.title }}</span>
                        </div>
                      </div>
                    </div>
                  </template>

                  <!-- 操作记录 tab -->
                  <template v-if="activeBottomTab === 'operation'">
                    <div class="opretaion-item" style="margin:10px 0" v-for="(record, index) in mockOperationRecord" :key="index">
                      <div class="item-header">
                        <span class="item-title">{{record.time}}</span>
                      </div>
                      <div class="item-description">
                         {{record.subjectName}}-{{record.action}}-{{record.chapter}}-{{record.objectName}}
                      </div>
                    </div>
                  </template>
                </div>
              </div>
            </el-collapse-transition>
          </div>
        </div>
      </main>
      <ChatAssistant
        v-model:visible="showConfigPanel"
        :width="chatAssistantWidth"
        @resize="handleChatResize"
        @resize-start="isResizingChat = true"
        @resize-end="isResizingChat = false"
        :current-chapter="currentChapter"
        :current-chapter-id="currentChapterId"
        :document-title="documentTitle"
        :project-id="currentDocumentId"
        :project-info="documents.find(d => d.id === currentDocumentId)?.projectInfo"
        @content-streaming="handleContentStreaming"
        @content-generated="handleContentGenerated"
      />
    </div>

    <!-- 文档创建向导 -->
    <el-dialog 
      v-model="showDocumentWizard" 
      title="新建文档" 
      width="800px"
      :close-on-click-modal="false"
      class="document-wizard-dialog"
      align-center
    >

      <div class="wizard-progress">
        <div class="progress-steps">
          <div 
            v-for="(step, index) in wizardSteps" 
            :key="step.id"
            class="step-item"
            :class="{ 
              'active': wizardStep === step.id, 
              'completed': step.completed 
            }"
          >
            <div class="step-icon">
              <el-icon v-if="step.completed">
                <CircleCheck />
              </el-icon>
              <el-icon v-else-if="wizardStep === step.id">
                <Check />
              </el-icon>
              <span v-else class="step-number">{{ step.id }}</span>
            </div>
            <div class="step-title">{{ step.title }}</div>
            <el-icon v-if="index < wizardSteps.length - 1" class="step-arrow">
              <ArrowRight />
            </el-icon>
          </div>
        </div>
      </div>

      <!-- 步骤内容 -->
      <div class="wizard-content">
        <!-- 步骤1: 文档关键信息 -->
        <div v-if="wizardStep === 1" class="step-content">
          
          <!-- 核心区域：文档名称 -->
          <div class="core-section">
            <div class="core-title">
              <el-icon class="core-icon">
                <Document />
              </el-icon>
              <span>文档名称</span>
            </div>
            <el-form-item class="core-form-item">
              <el-input 
                v-model="wizardForm.projectName" 
                placeholder="请输入文档名称"
                maxlength="50"
                show-word-limit
                size="large"
                class="core-input"
                clearable
                autofocus
              />
            </el-form-item>
          </div>

          <el-form :model="wizardForm" label-width="140px" class="project-form">
            <div class="form-section recognize-section">
              <el-card class="recognize-card">
                <div class="section-header">
                  <h4 class="section-title">项目信息识别</h4>
                  <el-button 
                    type="primary" 
                    :loading="recognizingProjectInfo"
                    :disabled="(!wizardForm.projectDescription?.trim() && uploadStatus !== 'success') || uploadStatus === 'uploading'"
                    @click="recognizeProjectInfo"
                    class="recognize-btn"
                    size="small"
                  >{{ recognizingProjectInfo ? '识别中...' : '识别' }}</el-button>
                </div>
                
                <div class="input-area-wrapper">
                  <el-input 
                    v-model="wizardForm.projectDescription" 
                    type="textarea"
                    :rows="12"
                    placeholder="请输入项目概况或上传项目相关文件（如设计说明、规划条件等）。点击识别后，系统能够识别各项关键信息（详见识别结果），以帮助您生成更准确的结果。

样例：本项目为“XX高中教学楼、宿舍楼”，位于XX市XX区，用地性质为教育用地；总建筑面积约10,000㎡，建筑高度50m，地上5层（地下1层）；结构体系为框架-剪力墙；抗震设防烈度7度；气候分区为夏热冬冷地区。"
                    maxlength="1200"
                    show-word-limit
                    resize="none"
                    class="project-desc-input"
                  />
                  
                  <div class="input-toolbar">
                    <div class="toolbar-left">
                      <el-upload
                        ref="uploadRef"
                        class="upload-trigger-container"
                        :show-file-list="false"
                        :http-request="handleFileUpload"
                        :before-upload="beforeUpload"
                        :multiple="false"
                        :limit="1"
                        :on-exceed="handleExceed"
                        :disabled="recognizingProjectInfo"
                        accept=".jpg,.jpeg,.png,.pdf,.docx"
                      >
                        <el-button link type="primary" :disabled="recognizingProjectInfo" class="upload-btn-enhanced">
                          <template #icon><el-icon class="upload-icon-enhanced"><Paperclip /></el-icon></template>
                          上传文件或图片
                        </el-button>
                      </el-upload>
                      <el-tooltip content="支持图片(png/jpg/jpeg, 不超过1MB)和 文件(pdf/docx, 不超过2MB)" placement="top">
                         <el-icon class="upload-tip-icon"><QuestionFilled /></el-icon>
                      </el-tooltip>
                    </div>
                    <div class="toolbar-right">
                       <div v-if="uploadedFileName" class="uploaded-file-tag" :class="uploadStatus">
                          <el-icon class="file-icon"><Document /></el-icon>
                          <span class="file-name">{{ uploadedFileName }}</span>
                          <span v-if="uploadStepText" class="upload-step">{{ uploadStepText }}</span>
                          <el-icon v-if="uploadStatus === 'success'" class="status-icon success"><CircleCheck /></el-icon>
                          <el-icon v-if="uploadStatus === 'error'" class="status-icon error"><Close /></el-icon>
                          <el-icon v-if="uploadStatus !== 'uploading'" class="delete-icon" @click.stop="removeUploadedFile"><Delete /></el-icon>
                       </div>
                    </div>
                  </div>
                </div>

                <div class="project-overview">
                  <el-card class="overview-card">
                    <div class="overview-header">
                      <div class="overview-title">识别结果</div>
                      <el-button size="small" type="primary" class="open-drawer" @click="openReviewDrawer">详情</el-button>
                    </div>
                    <div class="overview-stats">
                      <el-tag type="success">识别 {{ recognitionResult.total }} 项</el-tag>
                      <el-tag type="info">已应用 {{ recognitionResult.applied }}</el-tag>
                      <el-tag type="warning" v-if="recognitionResult.pending">待确认 {{ recognitionResult.pending }}</el-tag>
                    </div>
                    <div class="section-stats">
                      <el-space wrap>
                        <el-tag 
                          v-for="sec in sectionOrder" 
                          :key="sec" 
                          :type="(sectionCounts[sec]?.total || 0) > 0 && (sectionCounts[sec]?.recognized || 0) === (sectionCounts[sec]?.total || 0) ? 'success' : (sectionCounts[sec]?.recognized || 0) > 0 ? 'warning' : 'info'"
                        >
                          {{ sectionTitle(sec) }}：{{ sectionCounts[sec]?.recognized || 0 }}/{{ sectionCounts[sec]?.total || 0 }}
                        </el-tag>
                      </el-space>
                    </div>
                  </el-card>
                </div>
              </el-card>
            </div>
          </el-form>
        </div>

        <!-- 步骤2: 大纲 -->
        <div v-if="wizardStep === 2" class="step-content">
          <div class="step-header">
            <el-icon class="step-icon-large">
              <Document />
            </el-icon>
            <div class="step-info step-info-inline">
              <h3 class="step-title">目录大纲</h3>
              <p class="step-desc">可拖拽调整顺序，点击标题修改，点击右侧按钮增删</p>
            </div>
            <div class="step-actions">
              <el-tooltip content="开启后，将通过AI自动生成全文" placement="top">
                <span class="toggle-label">全文生成</span>
              </el-tooltip>
              <el-switch v-model="autoGenerateOnCreate" />
            </div>
          </div>
          
          <div class="outline-list">
            <!-- 递归渲染大纲项 -->
            <template v-for="(item, index) in outlineItems" :key="item.id">
              <!-- 主节点 -->
              <div 
                class="outline-item"
                draggable="true"
                @dragstart="handleDragStart($event, index)"
                @dragover="handleDragOver($event)"
                @drop="handleDrop($event, index)"
              >
                <div class="outline-item-content">
                  <div class="outline-left-actions">
                    <div class="add-btn" @click="addOutlineItemAfter(index)" title="添加章节">
                      <el-icon>
                        <Plus />
                      </el-icon>
                    </div>
                    <div class="drag-handle" title="拖拽排序">
                      <div class="three-dots">
                        <span></span>
                        <span></span>
                        <span></span>
                      </div>
                    </div>
                  </div>
                  <span class="outline-number">{{ getChineseNumber(index + 1) }}、</span>
                  <div 
                    class="outline-title"
                    contenteditable="true"
                    @blur="updateOutlineTitle(item.id, ($event.target as HTMLElement).textContent || '')"
                    @keydown.enter.prevent="($event.target as HTMLElement).blur()"
                  >
                    {{ item.title }}
                  </div>
                  <div class="outline-right-actions">
                    <!-- 展开/收起子节点按钮 -->
                    <div 
                      v-if="item.children && item.children.length > 0"
                      class="expand-btn" 
                      @click="toggleOutlineExpand(item.id)" 
                      :title="item.expanded ? '收起子节点' : '展开子节点'"
                    >
                      <el-icon :class="{ 'rotated': item.expanded }">
                        <ArrowRight />
                      </el-icon>
                    </div>
                    <div class="delete-btn" @click="removeOutlineItem(item.id)" title="删除章节">
                      <el-icon>
                        <Close />
                      </el-icon>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- 子节点 -->
              <div 
                v-if="item.children && item.children.length > 0 && item.expanded"
                class="sub-outline-container"
              >
                <div 
                  v-for="(subItem, subIndex) in item.children" 
                  :key="subItem.id"
                  class="outline-item sub-outline-item"
                  draggable="true"
                  @dragstart="handleSubDragStart($event, index, subIndex)"
                  @dragover="handleDragOver($event)"
                  @drop="handleSubDrop($event, index, subIndex)"
                >
                  <div class="outline-item-content">
                    <div class="outline-left-actions">
                      <div class="add-btn" @click="addSubOutlineItemAfter(index, subIndex)" title="添加子章节">
                        <el-icon>
                          <Plus />
                        </el-icon>
                      </div>
                      <div class="drag-handle" title="拖拽排序">
                        <div class="three-dots">
                          <span></span>
                          <span></span>
                          <span></span>
                        </div>
                      </div>
                    </div>
                    <span class="outline-number">{{ index + 1 }}.{{ subIndex + 1 }}</span>
                    <div 
                      class="outline-title"
                      contenteditable="true"
                      @blur="updateSubOutlineTitle(item.id, subItem.id, ($event.target as HTMLElement).textContent || '')"
                      @keydown.enter.prevent="($event.target as HTMLElement).blur()"
                    >
                      {{ subItem.title }}
                    </div>
                    <div class="outline-right-actions">
                      <div class="delete-btn" @click="removeSubOutlineItem(item.id, subItem.id)" title="删除子章节">
                        <el-icon>
                          <Close />
                        </el-icon>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </template>
          </div>
        </div>
      </div>
      <RecognizeResultDrawer v-model="showReviewDrawer" :wizardForm="wizardForm" :recognizedFields="recognizedFields" @clear-field="clearField" />

      <!-- 底部按钮 -->
      <template #footer>
        <div class="wizard-footer">
          <el-button @click="showDocumentWizard = false">取消</el-button>
          <el-button 
            v-if="wizardStep > 1" 
            @click="prevWizardStep"
          >
            上一步
          </el-button>
          <el-button 
            v-if="wizardStep < wizardSteps.length" 
            type="primary" 
            @click="nextWizardStep"
            :loading = "loadingNextStep"
            :icon="ArrowRight"
            icon-position="right"
          >
            下一步
          </el-button>
          <el-button 
            v-if="wizardStep === wizardSteps.length" 
            type="primary" 
            :icon = "Star"
            :loading = "loadingDocGenarate"
            @click="autoGenerateOnCreate ? generateDocumentDefault() : finishDocumentWizard()"
          >
            确认创建
          </el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 重命名文档对话框 -->
    <el-dialog 
      v-model="showRenameDialog" 
      title="重命名文档" 
      width="400px"
      :close-on-click-modal="false"
    >
      <el-form>
        <el-form-item label="文档名称">
          <el-input 
            v-model="editingDocumentName" 
            placeholder="请输入文档名称"
            maxlength="50"
            show-word-limit
          />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="showRenameDialog = false">取消</el-button>
          <el-button type="primary" @click="confirmRename">确定</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
/* 编辑器特定样式 */
.editor-page {
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.project-overview {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.overview-card {
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
}

.overview-title {
  font-weight: 600;
  color: var(--gray-800);
  margin-bottom: 0;
}

.overview-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.overview-stats {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.section-stats {
  margin-top: 4px;
}

.review-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 8px 0;
  border-bottom: 1px dashed var(--gray-200);
}

.section-title {
  font-weight: 600;
  font-size: 13px;
  color: var(--gray-700);
  margin: 6px 0 4px;
}

/* 优化的Header样式 */
.header {
  background: linear-gradient(135deg, #ffffff 0%, #fafbfc 100%);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  position: sticky;
  top: 0;
  z-index: 1000;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  backdrop-filter: blur(10px);
}

.header-left {
  display: flex;
  align-items: center;
  gap: var(--spacing-lg);
}

/* 折叠面板样式优化 */
/* 核心区域样式 */
.core-section {
  background: var(--gray-50);
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-lg);
  padding: 20px;
  margin-bottom: 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  transition: all 0.3s ease;
}

.core-section:hover {
  border-color: var(--primary-color);
  box-shadow: 0 4px 12px rgba(64, 123, 255, 0.08);
}

.core-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  color: var(--text-primary);
  font-size: 14px;
  font-weight: 600;
}

.core-icon {
  font-size: 16px;
  color: var(--primary-color);
}

.core-form-item {
  margin-bottom: 0;
}

:deep(.core-input .el-input__wrapper) {
  background: white;
  border: 1px solid var(--gray-300);
  border-radius: var(--radius-md);
  box-shadow: none;
  transition: all 0.3s ease;
}

:deep(.core-input .el-input__wrapper:hover) {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 2px rgba(64, 123, 255, 0.1);
}

:deep(.core-input .el-input__wrapper.is-focus) {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px rgba(64, 123, 255, 0.15);
}

:deep(.core-input .el-input__inner) {
  font-size: 15px;
  font-weight: 500;
  color: var(--text-primary);
}

:deep(.core-input .el-input__count) {
  background: var(--gray-100);
  color: var(--gray-500);
  border-radius: 4px;
  padding: 2px 6px;
  font-size: 12px;
}


.user-info {
  display: flex;
  align-items: center;
  gap: var(--spacing-lg);
}

.user-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, #3b82f6, #1d4ed8);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: 0 2px 8px rgba(59, 130, 246, 0.25);
  border: 2px solid rgba(255, 255, 255, 0.9);
}

.user-avatar:hover {
  transform: scale(1.05);
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.35);
}

.user-dropdown-info {
  padding: 4px 0;
  min-width: 150px;
}

.user-dropdown-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);
  margin-bottom: 4px;
}

.user-dropdown-email {
  font-size: 12px;
  color: var(--el-text-color-secondary);
}

.editor-container {
  display: grid;
  grid-template-columns: 280px 280px 1fr;
  height: calc(100vh - 56px);
  background: var(--gray-100);
  transition: grid-template-columns 0.3s ease;
}

.editor-container.resizing {
  transition: none;
  user-select: none;
}

.editor-container.with-config-panel {
  grid-template-columns: 280px 280px 1fr var(--chat-width, 380px);
}

/* 大纲折叠时的布局 */
.editor-container.outline-collapsed {
  grid-template-columns: 280px 48px 1fr;
}

.editor-container.outline-collapsed.with-config-panel {
  grid-template-columns: 280px 48px 1fr var(--chat-width, 380px);
}

/* 欢迎页时的布局调整 */
.editor-container.welcome-mode {
  grid-template-columns: 280px 1fr;
}

.editor-container.welcome-mode.with-config-panel {
  grid-template-columns: 280px 1fr var(--chat-width, 380px);
}

/* 文档编辑器容器 */
.document-editor {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.document-header {
  flex-shrink: 0;
  padding: 16px;
  padding-left: 24px;
  background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
  border-bottom: 1px solid #e4e7ed;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.document-header-content {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
  min-width: 0;
}

.wizard-progress {
  padding: 10px 24px;
  border-bottom: 1px solid var(--gray-200);
}

.progress-steps {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
}

.step-item {
  display: flex;
  align-items: center;
  gap: 8px;
  position: relative;
}

.step-icon {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--gray-200);
  color: var(--gray-500);
  font-size: 14px;
  font-weight: 600;
}

.step-item.active .step-icon {
  background: var(--primary-color);
  color: white;
}

.step-item.completed .step-icon {
  background: var(--success-color);
  color: white;
}

.step-title {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-700);
}

.step-item.active .step-title {
  color: var(--primary-color);
}

.step-item.completed .step-title {
  color: var(--success-color);
}

.step-arrow {
  color: var(--gray-400);
  font-size: 16px;
}

.wizard-content {
  padding: 20px;
  min-height: 300px;
}

.step-content {
  max-width: 700px;
  margin: 0 auto;
}

.step-header {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
  padding: 12px 20px;
  background: var(--gray-50);
  border-radius: 12px;
}

.step-info {
  display:flex;
}

.step-info.step-info-inline {
  display: flex;
  align-items: center;      /* 垂直居中，保持水平对齐 */
  gap: 12px;                /* 两者之间的间距 */
}
.step-title {
  margin: 0;                /* 去掉 h3 默认外边距 */
  font-weight: 600;         /* 保持加粗效果 */
}
.step-desc {
  margin: 0;                /* 与标题在同一行 */
  color: #666;              /* 次要描述颜色 */
}

.step-icon-large {
  font-size: 32px;
  color: var(--primary-color);
}

.step-actions {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 10px;
}

.toggle-label {
  font-size: 13px;
  color: var(--gray-700);
}


.project-form {
  max-height: 720px;
  overflow-y: auto;
  padding: 0 8px;
}

.project-form .el-form-item {
  margin-bottom: 16px;
}

.project-form .el-form-item__label {
  font-weight: 500;
  color: var(--gray-700);
}

.form-section {
  padding: 16px;
  padding-bottom: 6px;
  background: #fafafa;
  border-radius: 8px;
  border: 1px solid #f0f0f0;
}

/* 统一识别模块 */
.recognize-section {
  margin-bottom: 2px;
  padding: 0;
  background: transparent;
  border: none;
}
.recognize-section :deep(.el-card) {
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-lg);
}
.recognize-card {
  padding: 10px 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  transition: all 0.3s ease;
}
.recognize-card:hover {
  border-color: var(--primary-color);
  box-shadow: 0 4px 12px rgba(64, 123, 255, 0.08);
}
.recognize-tabs {
  margin-top: 8px;
}
.recognize-tabs :deep(.el-tabs__header) {
  margin-bottom: 8px;
}
.recognize-card .summary-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.recognize-card .summary-actions .action-group {
  display: flex;
  align-items: center;
  gap: 8px;
}

.recognize-card .summary-actions .status-group {
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.upload-area {
  width: 100%;
}
.upload-area :deep(.el-upload-dragger) {
  min-height: 270px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.upload-btn-enhanced {
  font-weight: 500;
}

.upload-icon-enhanced {
  font-size: 18px;
  font-weight: bold;
}

.upload-tip-icon {
  display: flex;
  align-items: center;
  color: var(--gray-400);
  cursor: help;
  font-size: 16px;
  transition: color 0.2s;
}

.upload-tip-icon:hover {
  color: var(--primary-color);
}

.upload-hint {
  margin-top: 8px;
  font-size: 12px;
  color: var(--gray-500);
  line-height: 1.4;
}

.el-tabs__content{
  margin-bottom: 6px;
}

/* 项目信息摘要样式 */
.project-summary {
  margin: 0;
  padding: 0;
  flex-shrink: 0;
}

.project-summary .el-tag {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
  border-radius: 6px;
  font-weight: 500;
  padding: 6px 12px;
  border: 1px solid #0ea5e9;
  color: #0369a1;
  font-size: 12px;
}

.section-title {
  margin: 0 0 16px 0;
  font-size: 14px;
  font-weight: 600;
  color: var(--gray-800);
  padding-bottom: 8px;
  border-bottom: 2px solid var(--primary-color);
  display: inline-block;
}

.wizard-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  padding-bottom: 6px;
  border-top: 1px solid var(--gray-200);
}

.recognition-summary {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  margin: 12px 0 16px 0;
  background: var(--gray-50);
  border: 1px solid var(--gray-200);
  border-radius: 8px;
}


.recognition-summary .summary-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 侧边栏 */
.sidebar-left {
  background: white;
  border-right: 1px solid var(--gray-200);
  overflow-y: auto;
}

.sidebar-header {
  padding: var(--spacing-md) var(--spacing-lg);
  border-bottom: 1px solid var(--gray-200);
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--gray-50);
}

.sidebar-header h3 {
  font-size: 14px;
  font-weight: 600;
  color: var(--gray-600);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}


.chapter-list {
  padding: var(--spacing-sm);
}

/* 编辑器主区域 */
.editor-main {
  background: white;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.editor-container.welcome-mode .editor-main {
  overflow-y: auto;
}

.document-title {
    font-size: 24px;
    font-weight: 700;
    cursor: text;
    color: #1f2937;
    line-height: 1.3;
    transition: all 0.2s ease;
    border-radius: 6px;
    padding: 4px 8px;
    margin: -4px -8px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex-shrink: 0;
}

.document-title:hover {
    background: #f1f5f9;
    padding: 4px 8px;
}

.document-title:focus {
    outline: 2px solid #3b82f6;
    background: white;
    padding: 4px 8px;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.editor-content {
    flex: 1;
    overflow: hidden;
    padding: 0;
    width: 100%;
    background: #ffffff;
    display: flex;
    flex-direction: column;
}

/* 自定义滚动条 */
.editor-content::-webkit-scrollbar {
  width: 10px;
}

.editor-content::-webkit-scrollbar-track {
  background: #f1f5f9;
}

.editor-content::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 5px;
}

.editor-content::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

.no-chapter-selected {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 400px;
  color: var(--gray-500);
}

.no-chapter-selected .empty-state {
  text-align: center;
}

.no-chapter-selected .empty-state p {
  margin-top: 16px;
  font-size: 16px;
  color: var(--gray-600);
}

/* 引用资料底部区域样式 */
.reference-materials-bottom {
  position: sticky;
  bottom: 0;
  background: white;
  border-top: 2px solid var(--gray-200);
  box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.1);
  z-index: 100;
  margin-top: 6px;
}

.reference-materials-bottom .reference-header {
  cursor: pointer;
  padding: 8px 24px;
  background: var(--gray-50);
  border-bottom: 1px solid var(--gray-200);
  display: flex;
  align-items: center;
  justify-content: space-between;
  transition: all 0.3s ease;
}

.reference-materials-bottom .reference-header:hover {
  background: var(--gray-100);
}

.reference-materials-bottom .reference-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--gray-800);
  display: flex;
  align-items: center;
  gap: 8px;
}

.bottom-tabs {
  display: flex;
  gap: 4px;
}

.bottom-tab {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-500);
  cursor: pointer;
  padding: 2px 10px;
  border-radius: 4px;
  transition: color 0.2s, background 0.2s;
}

.bottom-tab:hover {
  color: var(--primary-color);
  background: var(--primary-light, rgba(64, 158, 255, 0.08));
}

.bottom-tab.active {
  color: var(--primary-color);
  font-weight: 600;
  background: var(--primary-light, rgba(64, 158, 255, 0.1));
}

.reference-materials-bottom .reference-icon {
  transition: transform 0.3s ease;
  color: var(--primary-color);
}

.reference-materials-bottom .reference-icon.expanded {
  transform: rotate(90deg);
}

.reference-materials-bottom .collapsed-title {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-600);
}

.reference-materials-bottom .toggle-icon {
  font-size: 16px;
  color: var(--gray-400);
  transition: transform 0.3s ease, color 0.2s;
  transform: rotate(90deg);
  cursor: pointer;
}

.reference-materials-bottom .toggle-icon.expanded {
  transform: rotate(-90deg);
  color: var(--primary-color);
}

.reference-materials-bottom .reference-header:hover .toggle-icon {
  color: var(--primary-color);
}

/* 外层包装器，用于动画 */
.reference-materials-bottom .reference-content-wrapper {
  background: white;
}

/* 内层内容容器，设置高度限制和滚动 */
.reference-materials-bottom .reference-content {
  max-height: 35vh;
  overflow-y: auto;
  padding: 20px 24px;
  /* 优化滚动条样式 */
  scrollbar-width: thin;
  scrollbar-color: var(--gray-300) transparent;
}

.reference-materials-bottom .reference-content::-webkit-scrollbar {
  width: 6px;
}

.reference-materials-bottom .reference-content::-webkit-scrollbar-track {
  background: transparent;
}

.reference-materials-bottom .reference-content::-webkit-scrollbar-thumb {
  background-color: var(--gray-300);
  border-radius: 3px;
}

.reference-materials-bottom .reference-content::-webkit-scrollbar-thumb:hover {
  background-color: var(--gray-400);
}

.reference-materials-bottom .reference-section {
  margin-bottom: 20px;
}

.reference-materials-bottom .reference-section:last-child {
  margin-bottom: 0;
}

.reference-materials-bottom .section-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--gray-700);
  margin: 0 0 10px 0;
  padding-bottom: 6px;
  border-bottom: 1px solid var(--gray-200);
}

.reference-materials-bottom .reference-items {
  display: grid;
  gap: 10px;
}

.reference-materials-bottom .reference-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 12px;
  border: 1px dashed var(--gray-300);
  border-radius: 8px;
  background: var(--gray-50);
  color: var(--gray-600);
}

.reference-materials-bottom .reference-empty .empty-icon {
  color: var(--gray-400);
  font-size: 18px;
  margin-right: 8px;
}

.reference-materials-bottom .reference-empty .empty-text {
  font-size: 13px;
}

.reference-materials-bottom .reference-item {
  padding: 14px;
  background: var(--gray-50);
  border-radius: 8px;
  border-left: 4px solid var(--primary-color);
  transition: all 0.2s ease;
}

.reference-materials-bottom .reference-item:hover {
  background: var(--gray-100);
  transform: translateY(-1px);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.reference-materials-bottom .item-header {
  margin-bottom: 8px;
}

.reference-materials-bottom .item-title {
  font-weight: 600;
  color: var(--gray-800);
  font-size: 14px;
}

.reference-materials-bottom .item-description {
  color: var(--gray-600);
  font-size: 13px;
  line-height: 1.5;
}

.opretaion-item {
  padding: 14px;
  background: var(--gray-50);
  border-radius: 8px;
  margin: 10px 0px;
  border-left: 4px solid var(--primary-color);
  transition: all 0.2s ease;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .reference-materials-bottom {
    margin-top: 24px;
  }
  
  .reference-materials-bottom .reference-header {
    padding: 12px 16px;
  }
  
  .reference-materials-bottom .reference-title {
    font-size: 16px;
  }
  
  .reference-materials-bottom .reference-content {
    padding: 16px;
    max-height: 30vh;
  }
  
  .reference-materials-bottom .reference-item {
    padding: 10px;
  }
  
  .reference-materials-bottom .reference-section {
    margin-bottom: 16px;
  }
  
  .reference-materials-bottom .reference-items {
    gap: 8px;
  }
  
  .reference-materials-bottom .item-title {
    font-size: 13px;
  }
  
  .reference-materials-bottom .item-description {
    font-size: 12px;
  }
}

.document-operations {
  display: flex;
  flex-shrink: 0;
  
  .el-button {
    transition: all 0.2s ease;
    &:hover {
      transform: translateY(-1px);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }
  }
  .doc-op-btn {
    border-radius: 999px;
    font-weight: 600;
    padding: 6px 12px;
  }
  .doc-op-settings {
    background: #f3f4f6;
    border-color: #e5e7eb;
    color: #374151;
  }
  .doc-op-settings.active {
    background: #dbeafe;
    border-color: #1890ff;
    color: #1890ff;
  }
  .doc-op-exit {
    background: #f8fafc;
    border-color: #e5e7eb;
    color: #64748b;
  }
  .doc-op-exit:hover {
    background: #eef2f7;
    color: #374151;
  }
}

.document-meta {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  flex-shrink: 0;
  
  .el-tag {
    border-radius: 6px;
    font-weight: 500;
    padding: 4px 12px;
    transition: all 0.2s ease;
    white-space: nowrap;
    
    &:hover {
      transform: translateY(-1px);
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    }
  }

  .meta-view-btn {
    background: #ffffff;
    color: #1890ff;
    /* border-color: #1890ff; */
    transition: all 0.2s ease;
  }
  .meta-view-btn:hover {
    background: #ffffff;
    color: #1d4ed8;
    border-color: #1d4ed8;
    transform: translateY(-1px);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
}

.chapter-section {
  margin-bottom: 48px;
  padding: 24px;
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid #e4e7ed;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  transition: all 0.2s ease;
  
  &:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  }
}

.markdown-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  border-radius: 0;
  overflow: hidden;
  margin: 0;
  padding: 0;
  border: none;
}

.markdown-section :deep(.markdown-editor) {
  flex: 1;
  height: 100%;
  min-height: 0;
  border: none;
  border-radius: 0;
  box-shadow: none;
}


.chapter-actions {
  display: flex;
  gap: var(--spacing-sm);
}

.action-btn {
  padding: 6px 12px;
  background: var(--primary-color);
  color: white;
  border: none;
  border-radius: var(--radius-sm);
  font-size: 12px;
  cursor: pointer;
  transition: var(--transition);
}

.action-btn:hover {
  background: var(--primary-hover);
}

.action-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}


/* 右侧边栏样式已移至 AISidebar 组件 */


/* 右侧边栏 */
.sidebar-right {
  background: white;
  border-left: 1px solid var(--gray-200);
  display: flex;
  flex-direction: column;
}

/* 标签样式调整 */
.sidebar-tabs :deep(.el-tabs__header) {
  margin: 0;
  background: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
}

.sidebar-tabs :deep(.el-tabs__nav-wrap) {
  padding: 0;
}

.sidebar-tabs :deep(.el-tabs__nav) {
  width: 100%;
  display: flex;
}

.sidebar-tabs :deep(.el-tabs__item) {
  flex: 1;
  padding: 14px 20px;
  font-size: 14px;
  font-weight: 500;
  color: #6c757d;
  border-bottom: 3px solid transparent;
  transition: all 0.2s ease;
  text-align: center;
  background: transparent;
  border-right: none;
  border-left: none;
  border-top: none;
  border-radius: 0;
}

.sidebar-tabs :deep(.el-tabs__item:hover) {
  color: #409eff;
  background: rgba(64, 158, 255, 0.05);
}

.sidebar-tabs :deep(.el-tabs__item.is-active) {
  color: #409eff;
  background: white;
  border-bottom-color: #409eff;
  font-weight: 600;
}

.sidebar-tabs :deep(.el-tabs__item .el-icon) {
  margin-right: 6px;
  font-size: 16px;
}

.sidebar-tabs :deep(.el-tabs__active-bar) {
  height: 3px;
  background-color: #409eff;
}

.tab-content {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* AI助手 */
.ai-chat-container {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.ai-messages {
  flex: 1;
  overflow-y: auto;
  padding: var(--spacing-lg);
}

.ai-message {
  display: flex;
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-lg);
}

.message-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--primary-color), var(--accent-color));
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
}

.message-content {
  flex: 1;
  background: var(--gray-50);
  padding: var(--spacing-md);
  border-radius: var(--radius-md);
  font-size: 14px;
  line-height: 1.6;
}

.ai-message.user .message-content {
  background: var(--primary-light);
}

.ai-input-area {
    padding: 8px;
    border-top:1px solid var(--gray-200);
}

.ai-suggestions {
  list-style: none;
  margin-top: var(--spacing-md);
}

.ai-suggestions li {
  padding: 10px 14px;
  background: white;
  border: 1px solid var(--gray-300);
  border-radius: var(--radius-md);
  margin-bottom: var(--spacing-sm);
  cursor: pointer;
  transition: var(--transition);
  font-size: 13px;
}

.ai-suggestions li:hover {
  background: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
}

.knowledge-search {
    padding: 20px 10px;
    /* padding-bottom: 20px; */
}

/* 知识库 */
.knowledge-list {
  flex: 1;
  overflow-y: auto;
  padding: var(--spacing-md);
}

.knowledge-item {
  background: var(--gray-50);
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
  padding: var(--spacing-md);
  margin-bottom: var(--spacing-md);
  transition: var(--transition);
}

.knowledge-item:hover {
  box-shadow: var(--shadow-md);
  border-color: var(--primary-color);
}

.knowledge-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: var(--spacing-sm);
}

.knowledge-header h4 {
  font-size: 14px;
  font-weight: 600;
  color: var(--gray-900);
  flex: 1;
}

.knowledge-snippet {
  font-size: 13px;
  color: var(--gray-600);
  line-height: 1.6;
  margin-bottom: var(--spacing-sm);
}

.knowledge-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.usage {
  font-size: 11px;
  color: var(--gray-500);
}


/* 导出菜单 */
.export-menu {
  position: fixed;
  top: 70px;
  right: 200px;
  z-index: 1000;
}

.dropdown-menu {
  background: white;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  padding: 8px;
  min-width: 200px;
}

.menu-item {
  padding: 10px 14px;
  border-radius: 6px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 12px;
  transition: background 0.2s;
  font-size: 14px;
}

.menu-item:hover {
  background: var(--gray-100);
}

/* 文档大纲样式 */
.outline-list {
  padding: 12px;
  max-height: 720px;
  overflow-y: auto;
}

.outline-item {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  margin-bottom: 8px;
  transition: all 0.2s ease;
}

.outline-item:hover {
  border-color: #3b82f6;
  box-shadow: 0 2px 8px rgba(59, 130, 246, 0.1);
}

.outline-item-content {
  display: flex;
  align-items: center;
  padding: 5px 12px;
  gap: 10px;
}

.outline-left-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.outline-right-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}

.outline-number {
  font-weight: 600;
  color: #3b82f6;
  min-width: 30px;
  font-size: 14px;
}

.outline-title {
  flex: 1;
  font-size: 14px;
  color: #374151;
  padding: 4px 8px;
  border-radius: 4px;
  transition: all 0.2s ease;
  min-height: 20px;
  line-height: 1.4;
}

.outline-title:hover {
  background: #f8fafc;
}

.outline-title:focus {
  outline: 2px solid #3b82f6;
  background: white;
}

.add-btn, .delete-btn, .drag-handle, .expand-btn {
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s ease;
  color: #6b7280;
}

.add-btn:hover {
  /* background: #d1fae5; */
  background: #dbeafe;
  color: #059669;
}

.delete-btn:hover {
  color: #dc2626;
}

.drag-handle:hover {
  background: #f3f4f6;
  color: #374151;
}

.expand-btn:hover {
  background: #dbeafe;
  color: #3b82f6;
}

.drag-handle {
  cursor: grab;
}

.drag-handle:active {
  cursor: grabbing;
}

/* 展开按钮旋转动画 */
.expand-btn .el-icon {
  transition: transform 0.2s ease;
}

.expand-btn .el-icon.rotated {
  transform: rotate(90deg);
}

/* 子节点容器样式 */
.sub-outline-container {
  margin-left: 20px;
  margin-bottom: 8px;
  border-left: 2px solid #e5e7eb;
  padding-left: 12px;
}

.sub-outline-item {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  margin-bottom: 4px;
}

.sub-outline-item:hover {
  border-color: #3b82f6;
  background: #f1f5f9;
}

.sub-outline-item .outline-number {
  color: #64748b;
  font-size: 13px;
  min-width: 40px;
}

.sub-outline-item .outline-title {
  font-size: 13px;
  color: #475569;
}

/* 三个点样式 */
.three-dots {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  width: 12px;
  height: 16px;
}

.three-dots span {
  width: 3px;
  height: 3px;
  background-color: #6b7280;
  border-radius: 50%;
  display: block;
}

.drag-handle:hover .three-dots span {
  background-color: #374151;
}

/* 拖拽状态 */
.outline-item.dragging {
  opacity: 0.5;
  transform: rotate(2deg);
}

.outline-item.drag-over {
  border-color: #3b82f6;
  background: #eff6ff;
}


.config-header {
  padding: 16px 20px;
  border-bottom: 1px solid var(--gray-200);
  background: var(--gray-50);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.config-header h3 {
  font-size: 16px;
  font-weight: 600;
  color: var(--gray-900);
  margin: 0;
}

.close-btn {
  color: var(--gray-500);
  padding: 4px;
}

.close-btn:hover {
  color: var(--gray-700);
  background: var(--gray-200);
}

.config-content {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
}

.config-section {
  margin-bottom: 24px;
}

.config-label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-700);
  margin-bottom: 8px;
}

.config-textarea {
  width: 100%;
}

.config-textarea :deep(.el-textarea__inner) {
  border-radius: 6px;
  border: 1px solid var(--gray-300);
  font-size: 13px;
  line-height: 1.5;
  resize: vertical;
  min-height: 80px;
}

.config-textarea :deep(.el-textarea__inner):focus {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 2px rgba(64, 158, 255, 0.1);
}

/* 知识库选择样式 */
.knowledge-select {
  width: 100%;
}

.knowledge-select :deep(.el-select__wrapper) {
  border-radius: 6px;
  border: 1px solid var(--gray-300);
  min-height: 40px;
}

.knowledge-select :deep(.el-select__wrapper):focus-within {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 2px rgba(64, 158, 255, 0.1);
}

.knowledge-option-content {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 0;
}

.knowledge-icon {
  font-size: 16px;
  flex-shrink: 0;
}

.knowledge-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
}

.knowledge-name {
  font-size: 13px;
  font-weight: 500;
  color: var(--gray-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.knowledge-desc {
  font-size: 11px;
  color: var(--gray-500);
  margin-top: 2px;
}

.weight-item {
  margin-bottom: 20px;
}

.weight-label {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  font-size: 13px;
  color: var(--gray-700);
}

.weight-value {
  font-weight: 600;
  color: var(--primary-color);
}

.weight-slider {
  width: 100%;
}

.weight-slider :deep(.el-slider__runway) {
  height: 6px;
  background-color: var(--gray-200);
  border-radius: 3px;
}

.weight-slider :deep(.el-slider__bar) {
  background-color: var(--primary-color);
  border-radius: 3px;
}

.weight-slider :deep(.el-slider__button) {
  width: 16px;
  height: 16px;
  border: 2px solid var(--primary-color);
  background-color: white;
}

.weight-slider :deep(.el-slider__button:hover) {
  transform: scale(1.1);
}

/* 高级设置样式 */
.advanced-settings {
  padding: 0;
}
.reference-sort {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.sort-item {
  background: var(--gray-100);
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
  padding: 10px 12px;
  transition: var(--transition);
}

.sort-item:hover {
  box-shadow: var(--shadow-sm);
  border-color: var(--primary-color);
}

.sort-item.drag-over {
  border-color: var(--primary-color);
  background: var(--gray-50);
}

.sort-item-content {
  display: flex;
  align-items: center;
  gap: 10px;
}

.drag-handle {
  cursor: move;
  color: var(--gray-600);
}

.sort-item-title {
  font-size: 13px;
  color: var(--gray-800);
}

.weight-section {
  margin-top: 0;
}

.weight-section .config-label {
  margin-bottom: 16px;
  font-size: 13px;
  font-weight: 500;
  color: var(--gray-700);
}

/* 折叠面板样式优化 */
/* 核心区域样式 */
.core-section {
  background: var(--gray-50);
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-lg);
  padding: 20px;
  margin-bottom: 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  transition: all 0.3s ease;
}

.core-section:hover {
  border-color: var(--primary-color);
  box-shadow: 0 4px 12px rgba(64, 123, 255, 0.08);
}

.core-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  color: var(--text-primary);
  font-size: 14px;
  font-weight: 600;
}

.core-subtitle {
  margin-left: auto;
  font-size: 12px;
  color: var(--gray-500);
}

.core-icon {
  font-size: 16px;
  color: var(--primary-color);
}

.core-form-item {
  margin-bottom: 0;
}

:deep(.core-input .el-input__wrapper) {
  background: white;
  border: 1px solid var(--gray-300);
  border-radius: var(--radius-md);
  box-shadow: none;
  transition: all 0.3s ease;
}

:deep(.core-input .el-input__wrapper:hover) {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 2px rgba(64, 123, 255, 0.1);
}

:deep(.core-input .el-input__wrapper.is-focus) {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px rgba(64, 123, 255, 0.15);
}

:deep(.core-input .el-input__inner) {
  font-size: 15px;
  font-weight: 500;
  color: var(--text-primary);
}

:deep(.core-input .el-input__count) {
  background: var(--gray-100);
  color: var(--gray-500);
  border-radius: 4px;
  padding: 2px 6px;
  font-size: 12px;
}

.project-collapse {
  --el-collapse-header-height:42px;
}

:deep(.project-collapse) {
  margin-top: 20px;
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
}

:deep(.project-collapse .el-collapse-item__header) {
  background: var(--gray-50);
  border-bottom: 1px solid var(--gray-200);
  padding: 0 20px;
  font-weight: 500;
  color: var(--text-primary);
}

:deep(.project-collapse .el-collapse-item__content) {
  padding: 20px;
  background: white;
}

:deep(.project-collapse .el-collapse-item__wrap) {
  border-bottom: none;
}

:deep(.project-collapse .form-section) {
  margin-bottom: 0;
  padding: 0;
  border: none;
  background: transparent;
}

:deep(.project-collapse .form-section .section-title) {
  display: none; /* 隐藏原有的section-title，因为已经在collapse-item的title中显示 */
}

:deep(.el-collapse) {
  border: none;
}

:deep(.el-collapse-item__header) {
  height: 40px;
  line-height: 40px;
  background-color: var(--gray-50);
  border: 1px solid var(--gray-200);
  border-radius: 6px;
  padding: 0 12px;
  font-size: 13px;
  font-weight: 500;
  color: var(--gray-700);
  margin-bottom: 8px;
}

:deep(.el-collapse-item__content) {
  padding: 16px 0 0 0;
  border: none;
}

:deep(.el-collapse-item__wrap) {
  border: none;
}

.back-button:hover {
  background: var(--gray-100) !important;
  transform: translateX(-2px);
}

.toolbar-btn {
  font-weight: 500 !important;
  border-radius: 8px !important;
  transition: all 0.2s ease !important;
  box-shadow: none !important;
}

.toolbar-btn:hover {
  transform: translateY(-1px) !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1) !important;
}

.config-actions {
  margin-top: 32px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.generate-btn {
  width: 100%;
  height: 40px;
  font-size: 14px;
  font-weight: 500;
  border-radius: 6px;
}

.regenerate-btn {
  margin-left:0 !important;
  width: 100%;
  height: 40px;
  font-size: 14px;
  border-radius: 6px;
  border: 1px solid var(--gray-300);
  color: var(--gray-600);
  padding: 0 16px;
}

.regenerate-btn:hover {
  border-color: var(--primary-color);
  color: var(--primary-color);
}

/* 响应式设计 */
@media (max-width: 1600px) {
  .editor-container {
    grid-template-columns: 250px 250px 1fr 350px;
  }
}

@media (max-width: 1400px) {
  .editor-container {
    grid-template-columns: 220px 220px 1fr 320px;
  }
}

@media (max-width: 1200px) {
  .editor-container {
    grid-template-columns: 200px 200px 1fr 300px;
  }
}

@media (max-width: 1000px) {
  .editor-container {
    grid-template-columns: 1fr;
  }
  
  .sidebar-document-manager,
  .sidebar-left,
  .sidebar-right {
    display: none;
  }
}

/* 欢迎页样式 */
.welcome-page {
  min-height: 96vh;
  background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding-top: 30px;
  /* padding: clamp(12px, 3vh, 24px); */
}

.welcome-content {
  max-width: 800px;
  width: 100%;
  text-align: center;
  box-sizing: border-box;
  padding: 0 16px;
}

.welcome-header {
  margin-bottom: 32px;
}

.welcome-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.welcome-title {
  font-size: 36px;
  font-weight: 700;
  color: var(--gray-900);
  margin-bottom: 12px;
  background: linear-gradient(135deg, #1976d2 0%, #1565c0 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.welcome-subtitle {
  font-size: 16px;
  color: var(--gray-600);
  line-height: 1.6;
  margin-bottom: 0;
}

.welcome-actions {
  margin-bottom: 40px;
}

.welcome-cta-button {
  font-size: 16px !important;
  font-weight: 600 !important;
  padding: 16px 32px !important;
  background: linear-gradient(135deg, #1976d2 0%, #1565c0 100%) !important;
  border: none !important;
  border-radius: 12px !important;
  box-shadow: 0 8px 24px rgba(25, 118, 210, 0.3) !important;
  transition: all 0.3s ease !important;
}

.welcome-cta-button:hover {
  background: linear-gradient(135deg, #1565c0 0%, #0d47a1 100%) !important;
  transform: translateY(-2px) !important;
  box-shadow: 0 12px 32px rgba(25, 118, 210, 0.4) !important;
}

.welcome-cta-button .el-icon {
  font-size: 18px !important;
  margin-right: 8px !important;
}

.welcome-stats {
  display: flex;
  justify-content: center;
  gap: 48px;
  margin-bottom: 40px;
  padding: 24px;
  background: rgba(255, 255, 255, 0.8);
  border-radius: 16px;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.stat-item {
  text-align: center;
}

.stat-number {
  font-size: 28px;
  font-weight: 700;
  color: var(--primary-color);
  margin-bottom: 6px;
}

.stat-label {
  font-size: 13px;
  color: var(--gray-600);
  font-weight: 500;
}

.welcome-features {
  text-align: left;
  margin-top: clamp(12px, 2vh, 24px);
}

.features-title {
  font-size: clamp(18px, 3.4vh, 24px);
  font-weight: 600;
  color: var(--gray-900);
  margin-bottom: clamp(12px, 2.6vh, 24px);
  text-align: center;
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(240px, 1fr));
  gap: clamp(10px, 2.2vh, 20px);
}

.feature-card {
  background: rgba(255, 255, 255, 0.9);
  border-radius: 12px;
  padding: clamp(12px, 2.6vh, 20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  transition: all 0.3s ease;
}

.feature-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
  background: rgba(255, 255, 255, 0.95);
}

.feature-icon {
  font-size: clamp(20px, 3vh, 28px);
  margin-bottom: clamp(8px, 1.5vh, 12px);
}

.feature-title {
  font-size: clamp(13px, 2.4vh, 16px);
  font-weight: 600;
  color: var(--gray-900);
  margin-bottom: clamp(6px, 1.5vh, 8px);
}

.feature-desc {
  font-size: clamp(12px, 2.2vh, 13px);
  color: var(--gray-600);
  line-height: 1.4;
}

@media (max-width: 768px) {
  .welcome-page {
    padding: 20px;
  }
  
  .welcome-title {
    font-size: 36px;
  }
  
  .welcome-subtitle {
    font-size: 18px;
  }
  
  .welcome-stats {
    flex-direction: column;
    gap: 24px;
  }
  
  .features-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-height: 800px) {
  .welcome-title { font-size: 32px; }
  .welcome-subtitle { font-size: 15px; }
  .welcome-actions { margin-bottom: 28px; }
  .welcome-stats { gap: 24px; margin-bottom: 24px; padding: 16px; }
  .features-title { font-size: 20px; margin-bottom: 16px; }
  .features-grid { grid-template-columns: repeat(2, minmax(220px, 1fr)); gap: 14px; }
  .feature-card { padding: 16px; }
}

@media (max-height: 650px) {
  .welcome-title { font-size: 28px; }
  .welcome-subtitle { font-size: 14px; }
  .welcome-actions { margin-bottom: 20px; }
  .welcome-stats { gap: 16px; padding: 12px; }
}

@media (max-width: 768px) {
  .editor-container {
    flex-direction: column;
  }
  
  .sidebar-document-manager {
    width: 100%;
    height: auto;
    max-height: 200px;
    border-right: none;
    border-bottom: 1px solid var(--gray-200);
  }
  
  .editor-main {
    flex: 1;
  }
  
  .config-panel {
    width: 100%;
    height: auto;
    max-height: 300px;
    border-left: none;
    border-top: 1px solid var(--gray-200);
  }
}

/* 项目概况识别按钮样式 */
.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
  margin-bottom: 6px;
}

.section-header .section-title {
  margin: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.section-header .recognize-btn {
  font-size: 12px;
}
.status-group {
  margin-left: auto;
  display: flex;
  align-items: center;
}
.upload-progress-container {
  display: flex;
  align-items: center;
  gap: 12px;
}
.upload-progress-bar {
  width: 200px;
}

.step-text {
  font-size: 13px;
  color: var(--primary-color);
  font-weight: 500;
  min-width: 90px;
}
.upload-status-tag {
  margin-left: 8px;
}

/* Input Area & Toolbar Styles */
.input-area-wrapper {
  border: 1px solid var(--gray-300);
  border-radius: var(--radius-md);
  padding: 1px;
  background: white;
  transition: all 0.3s ease;
  margin-bottom: 16px;
}

.input-area-wrapper:hover {
  border-color: var(--gray-400);
}

.input-area-wrapper:focus-within {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 2px rgba(64, 123, 255, 0.1);
}

.project-desc-input :deep(.el-textarea__inner) {
  border: none;
  box-shadow: none;
  padding: 12px;
  resize: none;
  background: transparent;
}

.input-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  border-top: 1px solid var(--gray-200);
  background: var(--gray-50);
  border-bottom-left-radius: var(--radius-md);
  border-bottom-right-radius: var(--radius-md);
  min-height: 40px;
}

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 4px;
}

.toolbar-left .upload-trigger-container {
  display: flex;
  align-items: center;
}

.upload-tip {
  font-size: 12px;
  color: var(--gray-500);
}

.toolbar-right {
  display: flex;
  align-items: center;
}

.uploaded-file-tag {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 8px;
  background: white;
  border: 1px solid var(--gray-200);
  border-radius: 4px;
  font-size: 12px;
  color: var(--gray-700);
  max-width: 450px;
}

.uploaded-file-tag .file-name {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 200px;
}

.uploaded-file-tag.success {
  background: #f0fdf4;
  border-color: #bbf7d0;
  color: #15803d;
}

.uploaded-file-tag.error {
  background: #fef2f2;
  border-color: #fecaca;
  color: #b91c1c;
}

.uploaded-file-tag.uploading {
  background: #eff6ff;
  border-color: #bfdbfe;
  color: #1d4ed8;
}

.file-icon {
  font-size: 14px;
}

.status-icon {
  font-size: 14px;
}
.status-icon.success { color: var(--success-color); }
.status-icon.error { color: var(--danger-color); }

.delete-icon {
  cursor: pointer;
  color: var(--gray-400);
  transition: color 0.2s;
  margin-left: 4px;
}
.delete-icon:hover {
  color: var(--danger-color);
}
.upload-step {
  color: var(--primary-color);
  font-size: 11px;
  white-space: nowrap;
}
</style>
