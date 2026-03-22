export default function PageHeader({
  title,
  description,
  badge,
}: {
  title: string
  description: string
  badge?: string
}) {
  return (
    <div className="pageHeader">
      <div>
        {badge ? <div className="eyebrow">{badge}</div> : null}
        <h1 className="pageTitle">{title}</h1>
        <p className="pageDesc">{description}</p>
      </div>
    </div>
  )
}
