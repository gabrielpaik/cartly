import type { Meta, StoryObj } from '@storybook/react'

import StatCard from '../../components/StatCard'

const meta = {
  title: 'Admin/Components/StatCard',
  component: StatCard,
  args: {
    label: 'DAU',
    value: '128',
    note: '오늘 기준 활성 사용자',
  },
  decorators: [
    (Story) => (
      <div style={{ padding: 28, background: '#f6f7f9', minHeight: '100vh', maxWidth: 360 }}>
        <Story />
      </div>
    ),
  ],
} satisfies Meta<typeof StatCard>

export default meta

type Story = StoryObj<typeof meta>

export const Default: Story = {}

export const WithoutNote: Story = {
  args: {
    note: undefined,
    label: 'Scan Success',
    value: '71%',
  },
}
