export function formatRupiah(value: number | undefined | null): string {
  if (value === undefined || value === null) return 'Rp0'
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value)
}

export function formatDate(value: string | undefined | null): string {
  if (!value) return '—'
  const d = new Date(value)
  return new Intl.DateTimeFormat('id-ID', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  }).format(d)
}

export function formatDateShort(value: string | undefined | null): string {
  if (!value) return '—'
  const d = new Date(value)
  return new Intl.DateTimeFormat('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }).format(d)
}
