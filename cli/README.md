## Project Introduction

data-plane-cli is a command-line tool designed to help developers quickly create, deploy, and manage applications on data-plane.

## Quick Start

To install data-plane-cli, use npm:
```bash
npm install -g data-plane-cli
```

Once installation is complete, verify the installation using:
```bash
data-plane -v
```

To log in, use the login command with your personal access token (PAT), which can be obtained from User Settings -> Personal Access Tokens:
```bash
data-plane login <pat>
```

View the list of applications and initialize an application:
```bash
data-plane app list
data-plane app init <appId>
```

For more commands and usage:
```bash
data-plane -h
```

## Development

To begin development, follow the steps below:

1. Navigate to the cli directory in the terminal:
```bash
cd cli
```

2. Install the required dependencies: 
```bash
npm install
```

3. Run the watch command:
```bash
npm run watch
```

4. Open a new terminal and run link command:
```bash
npm link
```

5. Finally, verify that everything is working as expected:
```bash
data-plane -v
```

## File Tree

```
├── src
|  ├── action
|  |  ├── application
|  |  ├── auth
|  |  ├── dependency
|  |  ├── function
|  |  ├── policy
|  |  ├── storage
|  |  └── website
|  ├── api
|  |  └── v1
|  ├── command
|  |  ├── application
|  |  ├── auth
|  |  ├── dependency
|  |  ├── function
|  |  ├── policy
|  |  ├── storage
|  |  └── website
|  ├── common
|  ├── config
|  └── util
└── template
```
