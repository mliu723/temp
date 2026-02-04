import { createMemo, createResource } from "solid-js"
import { DialogSelect } from "@tui/ui/dialog-select"
import { useDialog } from "@tui/ui/dialog"
import { useToast } from "../ui/toast"

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

async function fetchRequirements(): Promise<FetchResult> {
  // If no API URL is configured, return mock data for testing
  if (!CONFIG.apiUrl) {
    return {
      items: [
        { id: "1", name: "Sample Requirement 1", description: "This is a sample requirement" },
        { id: "2", name: "Sample Requirement 2", description: "Another sample requirement" },
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

// ============================================================================
// MAIN DIALOG COMPONENT
// ============================================================================

export function DialogReq() {
  const dialog = useDialog()
  const toast = useToast()

  // Use createResource for async data fetching
  const [data] = createResource(() => fetchRequirements())

  // Show toast on first load with mock data
  createMemo(() => {
    const result = data()
    if (result && !CONFIG.apiUrl && result.items.length > 0) {
      toast.show({
        message: "Using sample data (configure OPENCODE_REQ_API_URL)",
        variant: "info",
      })
    }
    if (result?.error && CONFIG.apiUrl) {
      toast.error(result.error)
    }
  })

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
    return result.items.map((item: RequirementItem) => ({
      key: item,
      value: item,
      title: getDisplayValue(item, CONFIG.displayField),
      description: CONFIG.descriptionField
        ? getDisplayValue(item, CONFIG.descriptionField, "id")
        : getDisplayValue(item, "id", "") || "",
      onSelect: () => {
        dialog.clear()
        console.log("Selected requirement:", item)
        toast.show({
          message: `Selected: ${getDisplayValue(item, CONFIG.displayField)}`,
          variant: "info",
        })
      },
    }))
  })

  const title = createMemo(() => {
    const result = data()
    if (!result) return "Loading..."
    return "Select Requirement"
  })

  return <DialogSelect title={title()} options={options()} />
}
