import type { Meta, StoryObj } from '@storybook/react'

import AdsPage from '../../app/ads/page'
import CartsPage from '../../app/carts/page'
import ConfigPage from '../../app/config/page'
import ContentPage from '../../app/content/page'
import OverviewPage from '../../app/overview/page'
import ScanOpsPage from '../../app/scan-ops/page'
import UsersPage from '../../app/users/page'
import AdminShellPreview from '../support/AdminShellPreview'

const meta = {
  title: 'Admin/Pages/Review',
  parameters: {
    layout: 'fullscreen',
  },
} satisfies Meta

export default meta

type Story = StoryObj<typeof meta>

export const Overview: Story = {
  render: () => (
    <AdminShellPreview activeHref="/overview">
      <OverviewPage />
    </AdminShellPreview>
  ),
}

export const Users: Story = {
  render: () => (
    <AdminShellPreview activeHref="/users">
      <UsersPage />
    </AdminShellPreview>
  ),
}

export const ScanOps: Story = {
  render: () => (
    <AdminShellPreview activeHref="/scan-ops">
      <ScanOpsPage />
    </AdminShellPreview>
  ),
}

export const Carts: Story = {
  render: () => (
    <AdminShellPreview activeHref="/carts">
      <CartsPage />
    </AdminShellPreview>
  ),
}

export const Ads: Story = {
  render: () => (
    <AdminShellPreview activeHref="/ads">
      <AdsPage />
    </AdminShellPreview>
  ),
}

export const Content: Story = {
  render: () => (
    <AdminShellPreview activeHref="/content">
      <ContentPage />
    </AdminShellPreview>
  ),
}

export const Config: Story = {
  render: () => (
    <AdminShellPreview activeHref="/config">
      <ConfigPage />
    </AdminShellPreview>
  ),
}
