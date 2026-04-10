import type { Preview } from '@storybook/nextjs-vite'

import '../app/globals.css'

const preview: Preview = {
  parameters: {
    layout: 'fullscreen',
    nextjs: {
      appDirectory: true,
    },
    options: {
      storySort: {
        order: ['Admin', ['Pages', 'Components', 'Auth']],
      },
    },
  },
}

export default preview
