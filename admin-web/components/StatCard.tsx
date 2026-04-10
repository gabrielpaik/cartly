export default function StatCard({
  label,
  value,
  note,
}: {
  label: string
  value: string
  note?: string
}) {
  return (
    <div className="card statCard">
      <div className="kpiLabel">{label}</div>
      <div className="kpiValue">{value}</div>
      {note ? <div className="kpiNote">{note}</div> : null}
    </div>
  )
}
