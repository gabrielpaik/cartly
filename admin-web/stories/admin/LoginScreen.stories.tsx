import type { Meta, StoryObj } from '@storybook/react'

import LoginScreen from '../../components/LoginScreen'

const meta = {
  title: 'Admin/Auth/LoginScreen',
  component: LoginScreen,
  args: {
    nextPath: '/overview',
  },
} satisfies Meta<typeof LoginScreen>

export default meta

type Story = StoryObj<typeof meta>

export const Default: Story = {}

export const SessionExpired: Story = {
  args: {
    reason: 'expired',
  },
}
