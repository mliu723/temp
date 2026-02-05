import { createMemo, createResource } from "solid-js"
import { DialogSelect } from "@tui/ui/dialog-select"
import { useDialog } from "@tui/ui/dialog"
import { useSDK } from "@tui/context/sdk"
import { useRoute } from "@tui/context/route"
import { useLocal } from "@tui/context/local"
import { useToast } from "../ui/toast"
import { Identifier } from "@/id/id"

// ============================================================================
// CONFIGURATION - Environment variables for easy customization
// ============================================================================

const CONFIG = {
  // API1: List items endpoint
  apiUrl: process.env.OPENCODE_REQ_API_URL || "",
  // Request body for API1 (JSON string)
  requestBody: process.env.OPENCODE_REQ_BODY || "{}",
  // Path to array in response (e.g., "data.content")
  responsePath: process.env.OPENCODE_REQ_RESPONSE_PATH || "data.content",
  // Field to display as label (e.g., "name")
  displayField: process.env.OPENCODE_REQ_DISPLAY_FIELD || "name",
  // Field to use as description (optional)
  descriptionField: process.env.OPENCODE_REQ_DESCRIPTION_FIELD || "",
  // JWT token for authentication (optional)
  token: process.env.OPENCODE_REQ_TOKEN || "",

  // API2: Get details endpoint (optional, supports {id} placeholder)
  api2Url: process.env.OPENCODE_REQ_API2_URL || "",
  api2Method: process.env.OPENCODE_REQ_API2_METHOD || "GET",
  api2Body: process.env.OPENCODE_REQ_API2_BODY || "{}",
  // Field to use as ID for API2 call (default: "id")
  idField: process.env.OPENCODE_REQ_ID_FIELD || "id",
}

// ============================================================================
// TYPES
// ============================================================================

type RequirementItem = {
  [key: string]: any
}

type FetchResult = {
  items: RequirementItem[]
  error: string | null
}

type Action = "discuss" | "generate"

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getNestedValue(obj: any, path: string): any {
  if (!path) return obj
  return path.split(".").reduce((current, key) => current?.[key], obj)
}

function extractArray(data: any, path: string): any[] {
  const value = getNestedValue(data, path)
  return Array.isArray(value) ? value : []
}

function getDisplayValue(item: any, field: string, fallback = "id"): string {
  const value = getNestedValue(item, field)
  if (value !== undefined && value !== null) return String(value)

  for (const key of [fallback, "id", "name", "title"]) {
    if (item[key]) return String(item[key])
  }
  return String(JSON.stringify(item).slice(0, 50))
}

function replacePlaceholders(template: string, item: any): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => {
    const value = getNestedValue(item, key)
    return value !== undefined && value !== null ? String(value) : `{${key}}`
  })
}

async function fetchRequirements(): Promise<FetchResult> {
  // If no API URL is configured, return mock data for testing
  if (!CONFIG.apiUrl) {
    return {
      items: [
        { id: "REQ-001", name: "添加用户认证", description: "实现 JWT 认证" },
        { id: "REQ-002", name: "创建仪表板", description: "构建主仪表板界面" },
        { id: "REQ-003", name: "文件上传功能", description: "允许文件上传" },
      ],
      error: null,
    }
  }

  try {
    let requestBody: Record<string, any> = {}
    try {
      requestBody = JSON.parse(CONFIG.requestBody)
    } catch {
      requestBody = {}
    }

    const headers: Record<string, string> = { "Content-Type": "application/json" }
    if (CONFIG.token) {
      headers["Authorization"] = `Bearer ${CONFIG.token}`
    }

    const response = await fetch(CONFIG.apiUrl, {
      method: "POST",
      headers,
      body: JSON.stringify(requestBody),
    })

    if (!response.ok) {
      return {
        items: [],
        error: `API 请求失败: ${response.status} ${response.statusText}`,
      }
    }

    const data = await response.json()
    const items = extractArray(data, CONFIG.responsePath)

    if (items.length === 0) {
      return { items: [], error: "API 未返回任何需求" }
    }

    return { items, error: null }
  } catch (error) {
    return {
      items: [],
      error: error instanceof Error ? error.message : "获取需求失败",
    }
  }
}

async function fetchRequirementDetails(item: RequirementItem): Promise<{ data: any; error: string | null }> {
  // If no API2 URL is configured, return the item itself as details
  if (!CONFIG.api2Url) {
    return {
      data: item,
      error: null,
    }
  }

  try {
    // Extract the ID value directly from the item
    const itemId = getNestedValue(item, CONFIG.idField) ||
                   getNestedValue(item, "id") ||
                   getNestedValue(item, "requestId")

    if (!itemId) {
      return {
        data: null,
        error: `无法从需求中提取 ID (字段: ${CONFIG.idField})`,
      }
    }

    const api2Url = replacePlaceholders(CONFIG.api2Url, { ...item, id: itemId })
    let api2Body: Record<string, any> = {}

    try {
      api2Body = JSON.parse(CONFIG.api2Body)
      api2Body = JSON.parse(
        replacePlaceholders(JSON.stringify(api2Body), { ...item, id: itemId }),
      )
    } catch {
      api2Body = {}
    }

    const api2Headers: Record<string, string> = { "Content-Type": "application/json" }
    if (CONFIG.token) {
      api2Headers["Authorization"] = `Bearer ${CONFIG.token}`
    }

    const api2Response = await fetch(api2Url, {
      method: CONFIG.api2Method.toUpperCase(),
      headers: api2Headers,
      body:
        CONFIG.api2Method.toUpperCase() !== "GET"
          ? JSON.stringify(api2Body)
          : undefined,
    })

    if (!api2Response.ok) {
      return {
        data: null,
        error: `API2 请求失败: ${api2Response.status} ${api2Response.statusText}`,
      }
    }

    const api2Data = await api2Response.json()
    return { data: api2Data, error: null }
  } catch (error) {
    return {
      data: null,
      error: error instanceof Error ? error.message : "获取需求详情失败",
    }
  }
}

async function injectRequirementData(
  sessionID: string,
  requirementData: any,
  action: Action,
  agentName: string,
  model: { providerID: string; modelID: string },
  sdk: ReturnType<typeof useSDK>,
): Promise<void> {
  // Build the message with requirement data formatted cleanly
  const actionText =
    action === "generate"
      ? "根据此需求生成代码。"
      : "让我们讨论这个需求。"

  // Format requirement data in a readable way
  const requirementText = `\n\n--- 需求详情 ---\n${JSON.stringify(requirementData, null, 2)}\n--- 需求详情结束 ---`

  const fullText = actionText + requirementText

  // Send using the SDK client which properly handles all contexts
  await sdk.client.session.prompt({
    sessionID,
    messageID: Identifier.ascending("message"),
    agent: agentName,
    model,
    parts: [
      {
        id: Identifier.ascending("part"),
        type: "text",
        text: fullText,
      },
    ],
  })
}

// ============================================================================
// DIALOG COMPONENTS
// ============================================================================

/**
 * Dialog for selecting action after requirement is selected
 */
export function DialogReqAction(props: { item: RequirementItem; itemName: string }) {
  const sdk = useSDK()
  const route = useRoute()
  const dialog = useDialog()
  const toast = useToast()
  const local = useLocal()

  const [details] = createResource(() => fetchRequirementDetails(props.item))

  const options = createMemo(() => {
    const result = details()

    // Loading state
    if (!result) {
      return [
        {
          key: "loading",
          value: null as Action | null,
          title: "加载中...",
          description: "正在获取需求详情",
          disabled: true,
        },
      ]
    }

    // Error state
    if (result.error) {
      toast.error(result.error)
      dialog.clear()
      return []
    }

    // Show action options
    return [
      {
        key: "discuss",
        value: "discuss" as Action,
        title: "与 AI 讨论",
        description: "在实现之前讨论此需求",
        onSelect: async () => {
          await handleAction("discuss", result.data)
        },
      },
      {
        key: "generate",
        value: "generate" as Action,
        title: "直接生成代码",
        description: "立即开始实现此需求",
        onSelect: async () => {
          await handleAction("generate", result.data)
        },
      },
    ]
  })

  const handleAction = async (action: Action, data: any) => {
    try {
      // Get current agent and model
      const agent = local.agent.current()
      const model = local.model.current()

      if (!model) {
        toast.error("请先选择一个模型")
        return
      }

      // Get or create session
      let sessionID: string
      if (route.data.type === "session") {
        sessionID = route.data.sessionID
        // Already in session - navigate first (no-op but ensures UI update)
        route.navigate({ type: "session", sessionID })
      } else {
        const created = await sdk.client.session.create({})
        if (!created.data) {
          throw new Error("创建会话失败")
        }
        sessionID = created.data.id
        // Navigate to session immediately to update UI
        route.navigate({ type: "session", sessionID })
      }

      // Clear dialog immediately after navigation to close it
      dialog.clear()

      // Inject requirement data in background (non-blocking)
      injectRequirementData(sessionID, data, action, agent.name, model, sdk).catch(
        (error) => {
          toast.error(error instanceof Error ? error.message : "处理需求失败")
        },
      )
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "处理需求失败")
      dialog.clear()
    }
  }

  const title = createMemo(() => {
    const result = details()
    if (!result) return "加载中..."
    return `已选择: ${props.itemName}`
  })

  return <DialogSelect title={title()} options={options()} />
}

/**
 * Main dialog for selecting a requirement
 */
export function DialogReq() {
  const dialog = useDialog()

  // Use createResource for async data fetching
  const [data] = createResource(() => fetchRequirements())

  // Compute options reactively
  const options = createMemo(() => {
    const result = data()

    // Loading state
    if (!result) {
      return [
        {
          key: "loading",
          value: null,
          title: "加载中...",
          description: "正在获取需求列表",
          disabled: true,
        },
      ]
    }

    // Error state
    if (result.error && result.items.length === 0) {
      return [
        {
          key: "error",
          value: null,
          title: "错误",
          description: result.error,
          disabled: true,
        },
      ]
    }

    // Empty state
    if (result.items.length === 0) {
      return [
        {
          key: "empty",
          value: null,
          title: "未找到需求",
          description: "请配置 OPENCODE_REQ_API_URL 环境变量",
          disabled: true,
        },
      ]
    }

    // Show items
    return result.items.map((item: RequirementItem) => {
      const itemName = getDisplayValue(item, CONFIG.displayField)
      const itemId = getDisplayValue(item, "id", "")
      const creator = getDisplayValue(item, "creator", "")

      // Format: "creator | id"
      const description = creator
        ? `${creator} | ${itemId}`
        : itemId

      return {
        key: item,
        value: item,
        title: itemName,
        description: description,
        onSelect: () => {
          // Navigate to action dialog
          dialog.replace(() => (
            <DialogReqAction item={item} itemName={itemName} />
          ))
        },
      }
    })
  })

  const title = createMemo(() => {
    const result = data()
    if (!result) return "加载中..."
    return "选择需求"
  })

  return <DialogSelect title={title()} options={options()} />
}
