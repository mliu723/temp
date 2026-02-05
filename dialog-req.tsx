import { createMemo, createResource } from "solid-js"
import { DialogSelect } from "@tui/ui/dialog-select"
import { DialogPrompt } from "../ui/dialog-prompt"
import { useDialog } from "@tui/ui/dialog"
import { useSDK } from "@tui/context/sdk"
import { useRoute } from "@tui/context/route"
import { useLocal } from "@tui/context/local"
import { useToast } from "../ui/toast"
import { Identifier } from "@/id/id"

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
  // API1: Base URL (may contain query parameters as placeholders)
  // Example: "http://xxx/xxx?role=true&name={name}&pbi={pbi}"
  apiUrl: process.env.OPENCODE_REQ_API_URL || "",
  // Request body for POST request (JSON string)
  requestBody: process.env.OPENCODE_REQ_BODY || "{}",
  responsePath: process.env.OPENCODE_REQ_RESPONSE_PATH || "data.content",
  displayField: process.env.OPENCODE_REQ_DISPLAY_FIELD || "name",
  token: process.env.OPENCODE_REQ_TOKEN || "",

  // User parameters to collect (key = placeholder in URL, label = display name)
  // Example: [{ key: "name", label: "姓名" }, { key: "pbi", label: "PBI" }]
  userParams: parseUserParams(process.env.OPENCODE_REQ_USER_PARAMS || "name,pbi"),

  // API2: Get detailed docs endpoint
  api2Url: process.env.OPENCODE_REQ_API2_URL || "",
  requirementIdParam: process.env.OPENCODE_REQ_REQUIREMENT_ID_PARAM || "requirementId",
  requirementIdField: process.env.OPENCODE_REQ_REQUIREMENT_ID_FIELD || "requirementId",
  api2ResponsePath: process.env.OPENCODE_REQ_API2_RESPONSE_PATH || "data",

  // Custom prompt to show before requirement docs
  customPrompt: process.env.OPENCODE_REQ_CUSTOM_PROMPT || "对话将基于以下需求进行，请先不要开始编写代码",
}

/** Parse user params from comma-separated string or JSON array */
function parseUserParams(value: string): Array<{ key: string; label: string }> {
  try {
    // Try JSON parse first
    const parsed = JSON.parse(value)
    if (Array.isArray(parsed)) return parsed
  } catch {}

  // Fallback: comma-separated list of keys
  return value.split(",").filter(Boolean).map(key => ({
    key: key.trim(),
    label: key.trim(),
  }))
}

// ============================================================================
// TYPES
// ============================================================================

type RequirementItem = Record<string, any>
type FetchResult<T> = { data: T | null; error: string | null }
type UserParams = Record<string, string>

// ============================================================================
// UTILITIES
// ============================================================================

/** Get nested value from object using dot notation */
function getNestedValue(obj: any, path: string): any {
  if (!path) return obj
  return path.split(".").reduce((current, key) => current?.[key], obj)
}

/** Get display value from item with fallbacks */
function getDisplayValue(item: RequirementItem, field: string, fallback = "id"): string {
  const value = getNestedValue(item, field)
  if (value != null) return String(value)

  for (const key of [fallback, "id", "name", "title"]) {
    if (item[key]) return String(item[key])
  }
  return JSON.stringify(item).slice(0, 50)
}

/** Build auth headers */
function buildHeaders(): Record<string, string> {
  const headers: Record<string, string> = { "Content-Type": "application/json" }
  if (CONFIG.token) {
    headers["Authorization"] = `Bearer ${CONFIG.token}`
  }
  return headers
}

/** Build API2 URL with requirementId */
function buildApi2Url(requirementId: string): string {
  let url = CONFIG.api2Url
  if (url.includes("{id}")) {
    return url.replace("{id}", requirementId)
  }
  const parsed = new URL(url)
  parsed.searchParams.set(CONFIG.requirementIdParam, requirementId)
  return parsed.toString()
}

/** Build API1 URL with user parameters */
function buildApi1Url(params: UserParams): string {
  let url = CONFIG.apiUrl
  const placeholders = new Set<string>()

  // First, replace any {key} placeholders in the URL
  for (const [key, value] of Object.entries(params)) {
    const placeholder = `{${key}}`
    if (url.includes(placeholder)) {
      url = url.replace(placeholder, encodeURIComponent(value))
      placeholders.add(key)
    }
  }

  // Then, append any remaining params as query parameters
  const remainingParams = Object.entries(params).filter(([key]) => !placeholders.has(key))
  if (remainingParams.length > 0) {
    const parsed = new URL(url)
    for (const [key, value] of remainingParams) {
      parsed.searchParams.set(key, value)
    }
    url = parsed.toString()
  }

  return url
}

// ============================================================================
// API FUNCTIONS
// ============================================================================

/** Fetch requirements list from API1 */
async function fetchRequirements(userParams: UserParams): Promise<FetchResult<RequirementItem[]>> {
  if (!CONFIG.apiUrl) {
    return { data: null, error: "请配置 OPENCODE_REQ_API_URL 环境变量" }
  }

  try {
    const url = buildApi1Url(userParams)
    const body = JSON.parse(CONFIG.requestBody)
    const response = await fetch(url, {
      method: "POST",
      headers: buildHeaders(),
      body: JSON.stringify(body),
    })

    if (!response.ok) {
      return { data: null, error: `API 请求失败: ${response.status}` }
    }

    const data = await response.json()
    const items = getNestedValue(data, CONFIG.responsePath)

    if (!Array.isArray(items) || items.length === 0) {
      return { data: null, error: "API 未返回任何需求" }
    }

    return { data: items, error: null }
  } catch (error) {
    return { data: null, error: error instanceof Error ? error.message : "获取需求失败" }
  }
}

/** Fetch requirement details from API2 */
async function fetchRequirementDetails(item: RequirementItem): Promise<FetchResult<any>> {
  if (!CONFIG.api2Url) {
    return { data: item, error: null }
  }

  try {
    const requirementId = getNestedValue(item, CONFIG.requirementIdField) ||
                         getNestedValue(item, "requirementId") ||
                         getNestedValue(item, "id")

    if (!requirementId) {
      return { data: null, error: `无法从需求中提取 requirementId` }
    }

    const url = buildApi2Url(String(requirementId))
    const response = await fetch(url, { method: "GET", headers: buildHeaders() })

    if (!response.ok) {
      return { data: null, error: `API2 请求失败: ${response.status}` }
    }

    const data = await response.json()
    const docs = getNestedValue(data, CONFIG.api2ResponsePath) || data
    return { data: docs, error: null }
  } catch (error) {
    return { data: null, error: error instanceof Error ? error.message : "获取需求文档失败" }
  }
}

/** Inject requirement docs into session */
async function injectRequirementDocs(
  sessionID: string,
  docs: any,
  agentName: string,
  model: { providerID: string; modelID: string },
  sdk: ReturnType<typeof useSDK>,
): Promise<void> {
  let text = ""

  // Add custom prompt if configured
  if (CONFIG.customPrompt) {
    text += `${CONFIG.customPrompt}\n\n`
  }

  // Add requirement docs
  text += `--- 需求文档 ---\n${JSON.stringify(docs, null, 2)}\n--- 需求文档结束 ---\n`

  await sdk.client.session.prompt({
    sessionID,
    messageID: Identifier.ascending("message"),
    agent: agentName,
    model,
    parts: [{ id: Identifier.ascending("part"), type: "text", text }],
  })
}

// ============================================================================
// DIALOG COMPONENTS
// ============================================================================

/**
 * Collect user parameters using DialogPrompt, then show requirements list
 */
async function collectUserParamsAndShowList(dialog: ReturnType<typeof useDialog>, toast: ReturnType<typeof useToast>): Promise<void> {
  const userParams: Record<string, string> = {}

  for (const param of CONFIG.userParams) {
    const value = await DialogPrompt.show(dialog, `请输入${param.label}`, {
      placeholder: param.label,
    })

    if (!value) {
      toast.error(`请输入${param.label}`)
      dialog.clear()
      return
    }
    userParams[param.key] = value
  }

  dialog.replace(() => <DialogReqList userParams={userParams} />)
}

/**
 * Dialog for displaying and selecting requirements
 */
function DialogReqList(props: { userParams: UserParams }) {
  const sdk = useSDK()
  const route = useRoute()
  const dialog = useDialog()
  const toast = useToast()
  const local = useLocal()

  const [data] = createResource(() => fetchRequirements(props.userParams))

  const options = createMemo(() => {
    const result = data()

    // Loading state
    if (!result) {
      return [{ key: "loading", value: null, title: "加载中...", description: "正在获取需求列表", disabled: true }]
    }

    // Error state
    if (result.error) {
      return [{ key: "error", value: null, title: "错误", description: result.error, disabled: true }]
    }

    // Map items to options
    return result.data!.map((item) => {
      const name = getDisplayValue(item, CONFIG.displayField)
      const id = getDisplayValue(item, "id", "")
      const creator = getDisplayValue(item, "creator", "")
      const description = creator ? `${creator} | ${id}` : id

      return {
        key: item,
        value: item,
        title: name,
        description,
        onSelect: async () => handleSelect(item),
      }
    })
  })

  /** Handle requirement selection */
  async function handleSelect(item: RequirementItem): Promise<void> {
    try {
      const details = await fetchRequirementDetails(item)
      if (details.error) {
        toast.error(details.error)
        dialog.clear()
        return
      }

      const agent = local.agent.current()
      const model = local.model.current()
      if (!agent) return toast.error("请先选择一个代理")
      if (!model) return toast.error("请先选择一个模型")

      const sessionID = await getOrCreateSession()
      route.navigate({ type: "session", sessionID })
      dialog.clear()

      await injectRequirementDocs(sessionID, details.data, agent.name, model, sdk)
    } catch (error) {
      const msg = error instanceof Error ? error.message : "处理需求失败"
      toast.error(msg)
      dialog.clear()
    }
  }

  /** Get existing session or create new one */
  async function getOrCreateSession(): Promise<string> {
    if (route.data.type === "session") {
      route.navigate({ type: "session", sessionID: route.data.sessionID })
      return route.data.sessionID
    }
    const created = await sdk.client.session.create({})
    if (!created.data) throw new Error("创建会话失败")
    return created.data.id
  }

  const title = createMemo(() => data() ? "选择需求" : "加载中...")

  return <DialogSelect title={title()} options={options()} />
}

/**
 * Main entry point - shows params dialog if user params configured, otherwise shows list
 */
export function DialogReq() {
  const dialog = useDialog()
  const toast = useToast()

  // If user params configured, show input dialog first
  if (CONFIG.userParams.length > 0) {
    collectUserParamsAndShowList(dialog, toast)
    return null
  }

  // Otherwise, show list directly with empty params
  return <DialogReqList userParams={{}} />
}
