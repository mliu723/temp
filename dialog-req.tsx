import { createMemo, createSignal, onMount } from "solid-js"
import { DialogSelect } from "@tui/ui/dialog-select"
import { useDialog } from "@tui/ui/dialog"
import { useSDK } from "@tui/context/sdk"
import { useRoute } from "@tui/context/route"
import { useToast } from "../ui/toast"
import { useLocal } from "@tui/context/local"
import { Session } from "@/session"
import { MessageV2 } from "@/session/message-v2"
import { Identifier } from "@/id/id"
import { Provider } from "@/provider/provider"

// ============================================================================
// CONFIGURATION - Environment variables for easy customization
// ============================================================================

const CONFIG = {
  // API1: List items endpoint
  apiUrl: process.env.OPENCODE_REQ_API_URL || "https://api.example.com/requirements",
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
  // Example: "https://api.example.com/requirements/{id}"
  api2Url: process.env.OPENCODE_REQ_API2_URL || "",
  api2Method: process.env.OPENCODE_REQ_API2_METHOD || "GET",
  api2Body: process.env.OPENCODE_REQ_API2_BODY || "{}",
  // Field to use as ID for API2 call (default: "id")
  idField: process.env.OPENCODE_REQ_ID_FIELD || "id",
}

// ============================================================================
// HELPER FUNCTIONS - Extensible utilities
// ============================================================================

/**
 * Get nested value from object using dot-notation path
 * @example getNestedValue({ data: { items: [...] } }, 'data.items') -> [...]
 */
function getNestedValue(obj: any, path: string): any {
  if (!path) return obj
  return path.split(".").reduce((current, key) => current?.[key], obj)
}

/**
 * Replace placeholders like {id}, {name} with values from item
 */
function replacePlaceholders(template: string, item: any): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => {
    const value = getNestedValue(item, key)
    return value !== undefined && value !== null ? String(value) : `{${key}}`
  })
}

/**
 * Extract array from response using configured path
 */
function extractArray(data: any, path: string): any[] {
  const value = getNestedValue(data, path)
  return Array.isArray(value) ? value : []
}

/**
 * Get display string from item, with fallbacks
 */
function getDisplayValue(item: any, field: string, fallback = "id"): string {
  const value = getNestedValue(item, field)
  if (value !== undefined && value !== null) return String(value)

  // Fallback to common fields
  for (const key of [fallback, "id", "name", "title"]) {
    if (item[key]) return String(item[key])
  }
  return String(JSON.stringify(item).slice(0, 50))
}

/**
 * Get the last model from the session or use default
 */
async function getLastModel(sessionID: string) {
  for await (const item of MessageV2.stream(sessionID)) {
    if (item.info.role === "user" && item.info.model) return item.info.model
  }
  return Provider.defaultModel()
}

// ============================================================================
// DIALOG COMPONENT
// ============================================================================

export function DialogReq() {
  const sdk = useSDK()
  const route = useRoute()
  const dialog = useDialog()
  const toast = useToast()
  const local = useLocal()
  const [items, setItems] = createSignal<any[]>([])
  const [loading, setLoading] = createSignal(true)

  // Fetch from API1 on mount
  onMount(async () => {
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
        throw new Error(`API request failed: ${response.status} ${response.statusText}`)
      }

      const data = await response.json()
      const list = extractArray(data, CONFIG.responsePath)

      if (list.length === 0) {
        toast.error("API returned no items")
        dialog.clear()
        return
      }

      setItems(list)
    } catch (error) {
      toast.error(`Failed to fetch requirements: ${error}`)
      dialog.clear()
    } finally {
      setLoading(false)
    }
  })

  // Build options for DialogSelect
  const options = createMemo(() =>
    items().map((item) => ({
      title: getDisplayValue(item, CONFIG.displayField),
      description: CONFIG.descriptionField
        ? getDisplayValue(item, CONFIG.descriptionField, "id")
        : getDisplayValue(item, "id", "") || "",
      value: item,
      onSelect: async () => await handleSelection(item),
    })),
  )

  // Handle selection - call API2 and inject synthetic message
  async function handleSelection(item: any) {
    try {
      let data = item

      // Call API2 if configured
      if (CONFIG.api2Url) {
        const itemId = getDisplayValue(item, CONFIG.idField, "id")
        const api2Url = replacePlaceholders(CONFIG.api2Url, { ...item, id: itemId })
        let api2Body: Record<string, any> = {}

        try {
          api2Body = JSON.parse(CONFIG.api2Body)
          // Replace placeholders in body
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
          throw new Error(`API2 request failed: ${api2Response.status} ${api2Response.statusText}`)
        }

        data = await api2Response.json()
      }

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

      // Get the current model
      const currentModel = local.model.current()
      const model = currentModel ?? (await getLastModel(sessionID))

      // Create user message
      const userMsg: MessageV2.User = {
        id: Identifier.ascending("message"),
        sessionID,
        role: "user",
        time: { created: Date.now() },
        agent: "build",
        model,
      }
      await Session.updateMessage(userMsg)

      // Inject API2 response as synthetic part (visible to LLM, not to user)
      await Session.updatePart({
        id: Identifier.ascending("part"),
        messageID: userMsg.id,
        sessionID,
        type: "text",
        text: `User selected requirement from /req command. Here is the detailed requirement data:\n\n${JSON.stringify(data, null, 2)}`,
        synthetic: true, // Critical: LLM sees it, user doesn't
        time: { start: Date.now(), end: Date.now() },
      } satisfies MessageV2.TextPart)

      // Navigate to session if needed
      if (route.data.type !== "session") {
        route.navigate({ type: "session", sessionID })
      }

      dialog.clear()
    } catch (error) {
      toast.error(`Failed to load requirement details: ${error}`)
    }
  }

  if (loading()) {
    return <div class="p-4 text-center">Loading requirements...</div>
  }

  return <DialogSelect title="Select Requirement" options={options()} />
}
