# 跨平台剪贴板同步工具 - Go Gin项目结构说明

本文档详细说明了为“跨平台剪贴板同步工具”项目设计的Go Gin后端服务的基础文件夹结构。该结构旨在清晰地划分职责，便于开发、测试和维护，并为项目未来的扩展预留了充足的空间。

## 1. 项目根目录：`clipboard-sync-backend`

这是整个Go后端服务的根目录，所有相关的代码、配置和脚本都将放置在此目录下。

```
clipboard-sync-backend/
├── cmd/
├── configs/
├── internal/
├── pkg/
├── scripts/
├── web/
├── go.mod
├── go.sum
└── project_structure.md
```

## 2. 核心目录说明

### 2.1 `cmd/` (Commands)

该目录包含项目的可执行应用程序的入口点。每个子目录代表一个独立的应用程序。对于本剪贴板同步工具，我们主要有一个后端服务。

*   **`cmd/server/`**: 包含后端Gin服务的启动代码。
    *   `main.go`: Gin服务的入口文件，负责初始化路由、数据库连接、WebSocket服务器等。

    **设计理念**：将应用程序的入口点与核心业务逻辑分离。当项目变得复杂，需要多个独立的可执行文件时（例如，一个用于Web服务，一个用于后台任务处理），可以在`cmd/`下创建更多的子目录。

### 2.2 `configs/` (Configurations)

存放应用程序的各种配置文件，如数据库连接字符串、JWT密钥、端口号、日志级别等。这些配置通常会根据不同的环境（开发、测试、生产）进行区分。

*   `config.yaml` (示例): 存放应用程序的配置信息。

    **设计理念**：集中管理配置，方便修改和部署。可以使用Go的配置库（如Viper）来加载和管理这些配置。

### 2.3 `internal/` (Internal Packages)

该目录存放项目内部使用的私有包。这些包只能被本项目内部的代码导入和使用，不能被外部项目导入。这是Go语言项目结构中的一个重要约定，用于封装核心业务逻辑，防止不必要的外部依赖。

*   **`internal/api/`**: 存放Gin路由处理函数（Handlers）。每个文件可以对应一个或一组相关的API接口。
    *   `user.go`: 处理用户相关的API请求（注册、登录、登出）。
    *   `clipboard.go`: 处理剪贴板相关的API请求（同步、历史记录）。
    *   `team.go`: 处理团队相关的API请求（创建团队、管理成员、共享剪贴板）。

    **设计理念**：将HTTP请求的处理逻辑与业务逻辑分离，保持Handler的简洁性，主要负责请求解析、参数校验和调用业务服务。

*   **`internal/auth/`**: 存放认证和授权相关的逻辑，如JWT的生成、解析和验证，中间件等。
    *   `jwt.go`: JWT的生成、解析和验证。
    *   `middleware.go`: 认证中间件。

    **设计理念**：将安全相关的逻辑集中管理，提高代码复用性和安全性。

*   **`internal/models/`**: 存放应用程序的数据模型定义，通常对应数据库表结构。
    *   `user.go`: 用户模型。
    *   `clipboard_entry.go`: 剪贴板条目模型。
    *   `device.go`: 设备模型。
    *   `team.go`: 团队模型。
    *   `team_member.go`: 团队成员模型。

    **设计理念**：清晰地定义数据结构，便于数据库操作和数据传输。

*   **`internal/repository/`**: 存放数据访问层（Data Access Layer, DAL）的代码，负责与数据库进行交互。每个文件对应一个数据模型的CRUD操作。
    *   `user_repo.go`: 用户数据操作。
    *   `clipboard_repo.go`: 剪贴板数据操作。
    *   `device_repo.go`: 设备数据操作。
    *   `team_repo.go`: 团队数据操作。

    **设计理念**：将数据库操作逻辑与业务逻辑分离，便于更换数据库或ORM框架，提高可测试性。

*   **`internal/service/`**: 存放业务逻辑层（Business Logic Layer, BLL）的代码。这里是实现核心业务功能的地方，它会协调`repository`和`websocket`等包来完成复杂的业务流程。
    *   `user_service.go`: 用户业务逻辑（注册、登录、信息更新）。
    *   `clipboard_service.go`: 剪贴板同步、历史记录管理等核心业务逻辑。
    *   `team_service.go`: 团队创建、成员管理、共享剪贴板内容发布等业务逻辑。

    **设计理念**：封装业务规则，确保数据一致性和业务流程的正确性。这是应用程序的核心。

*   **`internal/websocket/`**: 存放WebSocket连接管理和消息处理逻辑。
    *   `manager.go`: WebSocket连接管理器，负责连接的注册、注销、消息广播等。
    *   `handler.go`: 处理WebSocket接收到的消息，并调用相应的业务服务。

    **设计理念**：将WebSocket的底层通信细节与上层业务逻辑分离，便于管理和扩展实时通信功能。

### 2.4 `pkg/` (Public Packages)

该目录存放可以被外部项目安全导入和使用的公共库代码。如果您的项目中有一些通用的工具函数、数据结构或算法，可以放在这里。对于本剪贴板工具，初期可能不会有很多公共包，但为未来扩展预留。

*   `pkg/utils/` (示例): 存放一些通用的工具函数，如加密解密、字符串处理等。

    **设计理念**：提供可复用的通用功能，减少代码重复。

### 2.5 `scripts/` (Scripts)

存放各种辅助脚本，如数据库迁移脚本、部署脚本、测试脚本、构建脚本等。

*   `db_migrate.sh` (示例): 数据库迁移脚本。
*   `deploy.sh` (示例): 部署脚本。

    **设计理念**：自动化重复性任务，提高开发和运维效率。

### 2.6 `web/` (Web Assets)

如果后端服务需要提供静态文件（如前端构建后的HTML、CSS、JavaScript文件），可以存放在此目录。Gin可以配置为提供静态文件服务。

*   `web/static/` (示例): 存放前端构建后的静态资源。

    **设计理念**：将前端静态资源与后端代码分离，便于独立开发和部署。

## 3. Go模块文件

*   `go.mod`: 定义模块路径和依赖关系。
*   `go.sum`: 记录模块依赖的校验和。

## 4. 第一阶段需求映射

根据第一阶段的需求（用户管理、核心文本同步、基本历史记录），该项目结构可以很好地支持：

*   **用户管理**：`internal/api/user.go` (Handlers), `internal/auth/` (JWT), `internal/models/user.go`, `internal/repository/user_repo.go`, `internal/service/user_service.go`。
*   **核心文本同步**：`internal/api/clipboard.go` (Handlers), `internal/websocket/` (WebSocket管理), `internal/models/clipboard_entry.go`, `internal/repository/clipboard_repo.go`, `internal/service/clipboard_service.go`。
*   **基本历史记录**：`internal/api/clipboard.go` (Handlers), `internal/models/clipboard_entry.go`, `internal/repository/clipboard_repo.go`, `internal/service/clipboard_service.go`。

`cmd/server/main.go`将负责初始化这些模块并启动Gin服务器和WebSocket服务。

## 5. 后续阶段扩展空间

该结构为后续阶段的需求预留了充足的扩展空间：

*   **图片同步**：`internal/api/clipboard.go`和`internal/service/clipboard_service.go`可以扩展处理图片数据。`internal/models/clipboard_entry.go`可以增加图片相关的字段。
*   **设备管理**：`internal/models/device.go`和`internal/repository/device_repo.go`可以用于存储和管理设备信息，`internal/api/user.go`或新增`internal/api/device.go`来提供设备管理接口。
*   **团队协作剪贴板**：`internal/models/team.go`, `internal/models/team_member.go`, `internal/repository/team_repo.go`, `internal/service/team_service.go`, `internal/api/team.go`等模块已经预留，可以直接在此基础上进行开发。
*   **安全与隐私**：`internal/auth/`可以扩展端到端加密相关的逻辑。
*   **性能优化**：通过模块化的设计，可以更容易地对特定模块进行性能优化或替换。

这个结构遵循了Go社区的常见实践，如“按功能组织”和“内部包”原则，有助于构建一个可维护、可扩展的Go应用。

