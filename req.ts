import z from "zod"
import { Tool } from "./tool"
import { Question } from "../question"
import DESCRIPTION from "./req.txt"

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

  // API2: Get details endpoint (optional, supports {id} placeholder)
  // Example: "https://api.example.com/requirements/{id}"
  api2Url: process.env.OPENCODE_REQ_API2_URL || "",
  api2Method: process.env.OPENCODE_REQ_API2_METHOD || "GET",
  api2Body: process.env.OPENCODE_REQ_API2_BODY || "{}",
  // Field to use as ID for API2 call (default: "id")
  idField: process.env.OPENCODE_REQ_ID_FIELD || "id",
}

// ============================================================================
// TYPES
// ============================================================================

type Metadata = {
  apiUrl: string
  selectedItem?: any
  selectedLabel?: string
  api2Url?: string
  api2Response?: any
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

// ============================================================================
// TOOL DEFINITION
// ============================================================================

export const ReqTool = Tool.define("req", {
  description: DESCRIPTION,

  parameters: z.object({
    // Override API URL (optional)
    url: z.string().describe("Override API endpoint URL").optional(),
    // Override response path (optional)
    path: z.string().describe("Override path to array in response").optional(),
  }),

  async execute(params, ctx) {
    // ========================================================================
    // STEP 1: Fetch list from API1
    // ========================================================================

    const apiUrl = params.url || CONFIG.apiUrl
    let requestBody: Record<string, any> = {}

    try {
      requestBody = JSON.parse(CONFIG.requestBody)
    } catch {
      requestBody = {}
    }

    const response = await fetch(apiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
      signal: ctx.abort,
    })

    if (!response.ok) {
      throw new Error(`API request failed: ${response.status} ${response.statusText}`)
    }

    const data = await response.json()
    const items = extractArray(data, params.path || CONFIG.responsePath)

    if (items.length === 0) {
      return {
        title: "No Items Found",
        output: `API returned no items. Response:\n${JSON.stringify(data, null, 2)}`,
        metadata: { apiUrl } satisfies Metadata,
      }
    }

    // ========================================================================
    // STEP 2: Present selection UI
    // ========================================================================

    const question = {
      question: "Select an item",
      header: "Items",
      options: items.map((item) => ({
        label: getDisplayValue(item, CONFIG.displayField),
        description: CONFIG.descriptionField
          ? getDisplayValue(item, CONFIG.descriptionField, "id")
          : getDisplayValue(item, "id", "") || "",
      })),
      multiple: false,
      custom: false,
    }

    const answers = await Question.ask({
      sessionID: ctx.sessionID,
      questions: [question],
      tool: ctx.callID ? { messageID: ctx.messageID, callID: ctx.callID } : undefined,
    }).catch((e) => {
      if (e instanceof Question.RejectedError) return undefined
      throw e
    })

    if (!answers?.[0]?.[0]) {
      return {
        title: "No Selection",
        output: "User dismissed the selection.",
        metadata: { apiUrl } satisfies Metadata,
      }
    }

    // Find selected item
    const selectedLabel = answers[0][0]
    const selectedItem = items.find(
      (item) => getDisplayValue(item, CONFIG.displayField) === selectedLabel
    )

    if (!selectedItem) {
      return {
        title: "Selection Error",
        output: `Could not find item: ${selectedLabel}`,
        metadata: { apiUrl, selectedLabel } satisfies Metadata,
      }
    }

    // ========================================================================
    // STEP 3: Optional API2 call for details
    // ========================================================================

    const displayLabel = getDisplayValue(selectedItem, CONFIG.displayField)

    if (!CONFIG.api2Url) {
      // No API2 configured, return selected item directly
      return {
        title: `Selected: ${displayLabel}`,
        output: `User selected: ${displayLabel}\n\nItem details:\n${JSON.stringify(selectedItem, null, 2)}\n\nYou can now discuss this item with the user.`,
        metadata: { apiUrl, selectedItem } satisfies Metadata,
      }
    }

    // Make API2 call
    const itemId = getDisplayValue(selectedItem, CONFIG.idField, "id")
    const api2Url = replacePlaceholders(CONFIG.api2Url, { ...selectedItem, id: itemId })
    let api2Body: Record<string, any> = {}

    try {
      api2Body = JSON.parse(CONFIG.api2Body)
      // Replace placeholders in body
      api2Body = JSON.parse(replacePlaceholders(JSON.stringify(api2Body), { ...selectedItem, id: itemId }))
    } catch {
      api2Body = {}
    }

    const api2Response = await fetch(api2Url, {
      method: CONFIG.api2Method.toUpperCase(),
      headers: { "Content-Type": "application/json" },
      body: CONFIG.api2Method.toUpperCase() !== "GET" ? JSON.stringify(api2Body) : undefined,
      signal: ctx.abort,
    })

    if (!api2Response.ok) {
      throw new Error(`API2 request failed: ${api2Response.status} ${api2Response.statusText}`)
    }

    const api2Data = await api2Response.json()

    return {
      title: `Selected: ${displayLabel}`,
      output: `User selected: ${displayLabel}\n\nDetails from API:\n${JSON.stringify(api2Data, null, 2)}\n\nYou can now discuss this data with the user.`,
      metadata: {
        apiUrl,
        selectedItem,
        api2Url,
        api2Response: api2Data,
      } satisfies Metadata,
    }
  },
})
