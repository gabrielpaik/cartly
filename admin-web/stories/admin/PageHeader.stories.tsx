import type { Meta, StoryObj } from '@storybook/react'

import PageHeader from '../../components/PageHeader'

const meta = {
  title: 'Admin/Components/PageHeader',
  component: PageHeader,
  args: {
    badge: 'Live data',
    title: 'Overview',
    description: '핵심 지표 요약',
    actionLabel: '오늘 데이터 갱신',
  },
  decorators: [
    (Story) => (
      <div style={{ padding: 28, background: '#f6f7f9', minHeight: '100vh' }}>
        <Story />
      </div>
    ),
  ],
} satisfies Meta<typeof PageHeader>

export default meta

type Story = StoryObj<typeof meta>

export const Default: Story = {}

export const WithRefreshAction: Story = {
  args: {
    refreshing: false,
    onRefresh: () => undefined,
  },
}

export const Refreshing: Story = {
  args: {
    badge: 'Loading...',
    refreshing: true,
    onRefresh: () => undefined,
  },
}

export const InlineRefresh: Story = {
  args: {
    onRefresh: () => undefined,
    inlineRefresh: true,
  },
}
