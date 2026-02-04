import { createMemo, createResource } from "solid-js"
import { DialogSelect } from "@tui/ui/dialog-select"
import { useDialog } from "@tui/ui/dialog"
import { useSDK } from "@tui/context/sdk"
import { useRoute } from "@tui/context/route"
import { useToast } from "../ui/toast"
import { Session } from "@/session"
import { MessageV2 } from "@/session/message-v2"
import { Identifier } from "@/id/id"
import { Provider } from "@/provider/provider"

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
        { id: "REQ-001", name: "Add user authentication", description: "Implement JWT auth" },
        { id: "REQ-002", name: "Create dashboard", description: "Build main dashboard UI" },
        { id: "REQ-003", name: "File upload feature", description: "Allow file uploads" },
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
        error: `API request failed: ${response.status} ${response.statusText}`,
      }
    }

    const data = await response.json()
    const items = extractArray(data, CONFIG.responsePath)

    if (items.length === 0) {
      return { items: [], error: "API returned no requirements" }
    }

    return { items, error: null }
  } catch (error) {
    return {
      items: [],
      error: error instanceof Error ? error.message : "Failed to fetch requirements",
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
    const itemId = getDisplayValue(item, CONFIG.idField, "id")
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
        error: `API2 request failed: ${api2Response.status} ${api2Response.statusText}`,
      }
    }

    const api2Data = await api2Response.json()
    return { data: api2Data, error: null }
  } catch (error) {
    return {
      data: null,
      error: error instanceof Error ? error.message : "Failed to fetch requirement details",
    }
  }
}

async function getLastModel(sessionID: string) {
  for await (const item of MessageV2.stream(sessionID)) {
    if (item.info.role === "user" && item.info.model) return item.info.model
  }
  return Provider.defaultModel()
}

async function injectRequirementData(
  sessionID: string,
  requirementData: any,
  action: Action,
): Promise<void> {
  const model = await getLastModel(sessionID)

  // Create user message with the requirement data as synthetic part
  const userMsg: MessageV2.User = {
    id: Identifier.ascending("message"),
    sessionID,
    role: "user",
    time: { created: Date.now() },
    agent: "build",
    model,
  }
  await Session.updateMessage(userMsg)

  // Inject requirement data as synthetic part (visible to LLM but not displayed to user)
  await Session.updatePart({
    id: Identifier.ascending("part"),
    messageID: userMsg.id,
    sessionID,
    type: "text",
    text: `User selected a requirement via /req command. Here is the detailed requirement data:\n\n${JSON.stringify(requirementData, null, 2)}`,
    synthetic: true,
    time: { start: Date.now(), end: Date.now() },
  } satisfies MessageV2.TextPart)

  // Add the user's chosen action as a visible part
  const actionText =
    action === "generate"
      ? "Generate code based on this requirement."
      : "Let's discuss this requirement."

  await Session.updatePart({
    id: Identifier.ascending("part"),
    messageID: userMsg.id,
    sessionID,
    type: "text",
    text: actionText,
    time: { start: Date.now(), end: Date.now() },
  } satisfies MessageV2.TextPart)
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

  const [details] = createResource(() => fetchRequirementDetails(props.item))

  const options = createMemo(() => {
    const result = details()

    // Loading state
    if (!result) {
      return [
        {
          key: "loading",
          value: null as Action | null,
          title: "Loading...",
          description: "Fetching requirement details",
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
        title: "Discuss with LLM",
        description: "Talk about the requirement before implementing",
        onSelect: async () => {
          await handleAction("discuss", result.data)
        },
      },
      {
        key: "generate",
        value: "generate" as Action,
        title: "Generate code directly",
        description: "Start implementing the requirement immediately",
        onSelect: async () => {
          await handleAction("generate", result.data)
        },
      },
    ]
  })

  const handleAction = async (action: Action, data: any) => {
    try {
      // Get or create session
      let sessionID: string
      if (route.data.type === "session") {
        sessionID = route.data.sessionID
      } else {
        const created = await sdk.client.session.create({})
        if (!created.data) {
          throw new Error("Failed to create session")
        }
        sessionID = created.data.id
      }

      // Inject requirement data with chosen action
      await injectRequirementData(sessionID, data, action)

      // Navigate to session if needed
      if (route.data.type !== "session") {
        route.navigate({ type: "session", sessionID })
      }

      dialog.clear()
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to process requirement")
    }
  }

  const title = createMemo(() => {
    const result = details()
    if (!result) return "Loading..."
    return `Selected: ${props.itemName}`
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
          title: "Loading...",
          description: "Fetching requirements",
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
          title: "Error",
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
          title: "No requirements found",
          description: "Configure OPENCODE_REQ_API_URL environment variable",
          disabled: true,
        },
      ]
    }

    // Show items
    return result.items.map((item: RequirementItem) => {
      const itemName = getDisplayValue(item, CONFIG.displayField)
      return {
        key: item,
        value: item,
        title: itemName,
        description: CONFIG.descriptionField
          ? getDisplayValue(item, CONFIG.descriptionField, "id")
          : getDisplayValue(item, "id", "") || "",
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
    if (!result) return "Loading..."
    return "Select Requirement"
  })

  return <DialogSelect title={title()} options={options()} />
}
