export type Role = 'kasir' | 'owner'

export type ServiceType = 'Kiloan' | 'Sepatu' | 'Boneka' | 'Karpet' | 'Jas'
export type PaymentStatus = 'Belum Lunas' | 'Lunas'
export type ProductionStatus = 'Antrean' | 'Dicuci' | 'Disetrika' | 'Siap Diambil' | 'Selesai'
export type ApprovalStatus = 'Pending' | 'Approved' | 'Rejected'

export const PRODUCTION_FLOW: ProductionStatus[] = [
  'Antrean', 'Dicuci', 'Disetrika', 'Siap Diambil', 'Selesai',
]

export const SERVICE_TYPES: ServiceType[] = ['Kiloan', 'Sepatu', 'Boneka', 'Karpet', 'Jas']

export interface User {
  id: number
  username: string
  role: Role
}

export interface OrderItem {
  id?: number
  order_item_id?: number
  service_type: ServiceType
  weight_quantity: number
  price_per_unit: number
}

export interface Order {
  id: number
  tracking_code: string
  customer_id: number
  customer_name: string
  customer_phone?: string
  items?: OrderItem[]
  subtotal: number
  discount: number
  tax: number
  tax_rate: number
  grand_total: number
  payment_status: PaymentStatus
  current_status: ProductionStatus
  is_locked: boolean
  is_cancelled: boolean
  queue_number?: number
  order_date: string
}

export interface Paginated<T> {
  data: T[]
  pagination: {
    page: number
    page_size: number
    total: number
    total_pages: number
  }
}

export interface Customer {
  id: number
  name: string
  phone: string
  created_at?: string
  total_orders?: number
}

export interface EditRequestItem {
  order_item_id: number
  service_type?: ServiceType
  old_service_type?: ServiceType
  new_service_type?: ServiceType
  old_weight_quantity?: number
  new_weight_quantity?: number
  old_price_per_unit?: number
  new_price_per_unit?: number
}

export interface EditRequest {
  id: number
  order_id: number
  reason: string
  approval_status: ApprovalStatus
  is_cancellation_request: boolean
  items?: EditRequestItem[]
  created_at: string
  requested_by?: string
}

export interface TrackingInfo {
  tracking_code: string
  customer_name: string
  current_status: ProductionStatus
  status_progress: number
  is_cancelled: boolean
  queue_position?: number
  queue_ahead?: number
  items: OrderItem[]
  subtotal: number
  discount: number
  tax: number
  grand_total: number
  order_date: string
}

export interface FinancialSummary {
  period: string
  revenue: number
  order_count: number
}

export interface FinancialAnalytics {
  summaries: FinancialSummary[]
  overall: {
    revenue: number
    order_count: number
  }
}

export interface ServiceBreakdownItem {
  service_type: ServiceType
  revenue: number
  total_weight_quantity?: number
  order_count?: number
}
