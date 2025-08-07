-- SQL Schema for LinkDeck (PostgreSQL)

-- 启用 UUID 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 用户表 (Users)
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    auth_provider VARCHAR(50) DEFAULT 'email_password' NOT NULL, -- 'email_password', 'github', 'google', 'wechat'
    is_pro_user BOOLEAN DEFAULT FALSE NOT NULL,
    last_login_at TIMESTAMP WITH TIME ZONE,
    profile_picture_url VARCHAR(255),
    preferred_language VARCHAR(10) DEFAULT 'en-US' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 索引: 优化登录和查找
CREATE INDEX idx_users_username ON users (username);
CREATE INDEX idx_users_email ON users (email);

-- 模板表 (Templates)
-- 存储官方模板和用户自定义模板
CREATE TABLE templates (
    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_name VARCHAR(255) NOT NULL,
    template_description TEXT,
    is_official BOOLEAN DEFAULT FALSE NOT NULL, -- 是否为官方模板
    is_public BOOLEAN DEFAULT FALSE NOT NULL, -- 模板是否公开可见
    creator_user_id UUID, -- 如果是用户创建的模板，关联到用户ID
    preview_image_url VARCHAR(255), -- 模板预览图
    template_data JSONB NOT NULL, -- 存储模板的结构化数据，如模块列表、默认配置等
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (creator_user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 索引: 优化模板查找
CREATE INDEX idx_templates_is_official ON templates (is_official);
CREATE INDEX idx_templates_is_public ON templates (is_public);

-- 用户主页表 (User_Pages)
-- 每个用户可以有多个主页，但通常只有一个活跃主页
CREATE TABLE user_pages (
    page_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    page_slug VARCHAR(100) UNIQUE NOT NULL, -- 用于生成 linkdeck.com/username 或 custom_domain/slug
    page_title VARCHAR(255) DEFAULT '我的主页' NOT NULL,
    page_description TEXT, -- 用于SEO
    seo_keywords TEXT, -- SEO关键词
    social_share_image_url VARCHAR(255), -- 社交分享图片
    custom_domain VARCHAR(255) UNIQUE, -- 绑定自定义域名
    is_active BOOLEAN DEFAULT TRUE NOT NULL, -- 是否为当前活跃主页
    template_id UUID, -- 当前主页使用的模板
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (template_id) REFERENCES templates(template_id) ON DELETE SET NULL
);

-- 索引: 优化主页查找和用户关联
CREATE INDEX idx_user_pages_user_id ON user_pages (user_id);
CREATE UNIQUE INDEX uix_user_pages_user_id_is_active ON user_pages (user_id) WHERE is_active = TRUE;
CREATE INDEX idx_user_pages_page_slug ON user_pages (page_slug);

-- 模块表 (Modules)
-- 存储用户主页上的所有模块实例，例如链接模块、GitHub模块等
CREATE TABLE modules (
    module_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    page_id UUID NOT NULL,
    module_type VARCHAR(50) NOT NULL, -- 例如 'link', 'github', 'rss', 'spotify', 'text', 'image', 'video'
    module_title VARCHAR(255), -- 模块的标题，例如链接模块的标题
    module_icon_url VARCHAR(255), -- 模块的图标URL
    module_order INT NOT NULL, -- 模块在页面上的顺序
    is_enabled BOOLEAN DEFAULT TRUE NOT NULL, -- 模块是否启用
    config JSONB NOT NULL, -- 存储模块的特定配置，例如链接URL、GitHub用户名、RSS源URL等
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (page_id) REFERENCES user_pages(page_id) ON DELETE CASCADE
);

-- 索引: 优化模块查找和页面关联
CREATE INDEX idx_modules_page_id ON modules (page_id, module_order);

-- 主页外观配置表 (Page_Appearance_Configs)
-- 存储用户主页的整体外观设置，如主题、背景、字体、自定义CSS等
CREATE TABLE page_appearance_configs (
    page_id UUID PRIMARY KEY,
    theme_id UUID, -- 关联到预设主题表 (如果存在)
    background_type VARCHAR(20) DEFAULT 'color' NOT NULL, -- 'color', 'gradient', 'image'
    background_value TEXT, -- 颜色值、渐变CSS、图片URL
    font_family VARCHAR(100),
    custom_css_code TEXT, -- 自定义CSS代码
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (page_id) REFERENCES user_pages(page_id) ON DELETE CASCADE
    -- FOREIGN KEY (theme_id) REFERENCES themes(theme_id) ON DELETE SET NULL -- 如果有themes表
);

-- 访问统计表 (Page_Analytics)
-- 存储用户主页的访问数据
CREATE TABLE page_analytics (
    record_id BIGSERIAL PRIMARY KEY,
    page_id UUID NOT NULL,
    visit_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    visitor_ip INET, -- 访客IP地址
    country_code CHAR(2), -- 访客国家代码 (ISO 3166-1 alpha-2)
    device_type VARCHAR(50), -- 'mobile', 'tablet', 'desktop'
    referrer_url VARCHAR(2048), -- 访客来源URL
    user_agent TEXT, -- 访客User-Agent
    FOREIGN KEY (page_id) REFERENCES user_pages(page_id) ON DELETE CASCADE
);

-- 索引: 优化分析查询
CREATE INDEX idx_page_analytics_page_id_visit_time ON page_analytics (page_id, visit_time DESC);
CREATE INDEX idx_page_analytics_country_code ON page_analytics (country_code);
CREATE INDEX idx_page_analytics_device_type ON page_analytics (device_type);

-- 模块点击统计表 (Module_Click_Analytics)
-- 存储主页上各个模块的点击数据
CREATE TABLE module_click_analytics (
    click_id BIGSERIAL PRIMARY KEY,
    module_id UUID NOT NULL,
    page_id UUID NOT NULL,
    click_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (module_id) REFERENCES modules(module_id) ON DELETE CASCADE,
    FOREIGN KEY (page_id) REFERENCES user_pages(page_id) ON DELETE CASCADE
);

-- 索引: 优化点击统计查询
CREATE INDEX idx_module_clicks_module_id_click_time ON module_click_analytics (module_id, click_time DESC);

-- 支付交易表 (Payments)
-- 存储用户的付费订阅和交易记录
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    subscription_plan VARCHAR(50) NOT NULL, -- 'Pro_Monthly', 'Pro_Yearly'
    amount NUMERIC(10, 2) NOT NULL, -- 支付金额
    currency CHAR(3) NOT NULL, -- 货币代码 (e.g., 'USD', 'CNY')
    payment_gateway VARCHAR(50) NOT NULL, -- 'Stripe', 'Alipay', 'WeChatPay'
    transaction_id VARCHAR(255) UNIQUE NOT NULL, -- 支付网关返回的交易ID
    status VARCHAR(20) NOT NULL, -- 'pending', 'completed', 'failed', 'refunded'
    payment_method_details JSONB, -- 支付方式的详细信息
    subscription_start_date TIMESTAMP WITH TIME ZONE,
    subscription_end_date TIMESTAMP WITH TIME ZONE,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 索引: 优化支付记录查找
CREATE INDEX idx_payments_user_id ON payments (user_id);
CREATE INDEX idx_payments_transaction_id ON payments (transaction_id);

-- 社交账号绑定表 (Social_Accounts)
-- 存储用户绑定的第三方社交账号信息，用于动态模块数据拉取和授权登录
-- 考虑敏感信息加密存储
CREATE TABLE social_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    platform VARCHAR(50) NOT NULL, -- 'github', 'google', 'wechat', 'spotify', 'steam', 'twitter', 'instagram', 'linkedin', 'telegram', 'youtube', 'bilibili', 'medium', 'rss'
    access_token TEXT NOT NULL, -- 存储访问令牌，需要加密处理
    refresh_token TEXT, -- 存储刷新令牌，需要加密处理
    expires_at TIMESTAMP WITH TIME ZONE, -- 令牌过期时间
    profile_info JSONB, -- 存储从第三方平台拉取的用户公开信息，如GitHub用户名、Spotify用户名等
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE (user_id, platform),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 索引: 优化社交账号查找
CREATE INDEX idx_social_accounts_user_id_platform ON social_accounts (user_id, platform);

-- 预设主题表 (Themes)
-- 存储官方或社区贡献的预设主题
CREATE TABLE themes (
    theme_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    theme_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_official BOOLEAN DEFAULT FALSE NOT NULL,
    creator_user_id UUID, -- 如果是用户贡献的主题
    preview_image_url VARCHAR(255), -- 主题预览图
    theme_data JSONB NOT NULL, -- 存储主题的样式配置（颜色、字体、布局等）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (creator_user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 索引: 优化主题查找
CREATE INDEX idx_themes_is_official ON themes (is_official);

-- 模板分类表 (Template_Categories)
-- 用于对模板进行分类，方便用户查找
CREATE TABLE categories (
    category_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_name VARCHAR(100) UNIQUE NOT NULL
);

-- 模板与分类关联表 (Template_Category_Junction)
CREATE TABLE template_categories (
    template_id UUID NOT NULL,
    category_id UUID NOT NULL,
    PRIMARY KEY (template_id, category_id),
    FOREIGN KEY (template_id) REFERENCES templates(template_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- 优惠码/折扣表 (Discount_Codes)
-- 用于管理付费套餐的优惠码
CREATE TABLE discount_codes (
    code_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    discount_percentage NUMERIC(5, 2) NOT NULL, -- 折扣百分比，例如 0.15 代表 15% 折扣
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
    max_uses INT DEFAULT 0, -- 最大使用次数，0表示无限制
    current_uses INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 审计日志表 (Audit_Logs)
-- 记录关键用户操作，用于安全审计和问题追踪
CREATE TABLE audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    user_id UUID,
    action_type VARCHAR(100) NOT NULL, -- e.g., 'user_login', 'page_created', 'module_added', 'payment_success'
    action_details JSONB,
    ip_address INET,
    user_agent TEXT, -- 用户代理
    request_details JSONB, -- 请求的详细信息，如URL, headers等
    timestamp_utc TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 国际化文本资源表 (I18n_Texts)
-- 存储所有需要国际化的文本内容，按语言和键值对存储
-- 适用于需要动态加载或管理多语言文本的场景
CREATE TABLE i18n_texts (
    text_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lang_code VARCHAR(10) NOT NULL, -- e.g., 'en-US', 'zh-CN'
    key_name VARCHAR(255) NOT NULL, -- 文本内容的唯一键
    text_content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE (lang_code, key_name)
);

-- 邮件通知队列 (Email_Notifications)
-- 用于存储待发送的邮件通知，例如注册确认、密码重置、Pro功能解锁等
CREATE TABLE email_notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    recipient_email VARCHAR(255) NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    html_body TEXT,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL, -- 'pending', 'sent', 'failed'
    sent_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 任务队列 (Task_Queue)
-- 用于异步处理后台任务，例如数据抓取、CDN缓存刷新、图片处理等
-- 任务内容可以存储为JSONB，根据task_type进行解析
CREATE TABLE task_queue (
    task_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_type VARCHAR(100) NOT NULL, -- e.g., 'github_data_sync', 'rss_fetch', 'cdn_purge', 'image_optimize'
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL, -- 'pending', 'processing', 'completed', 'failed'
    scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retries INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 外部集成配置表 (External_Integrations)
-- 存储第三方API的平台级配置，例如API密钥、回调URL等，需要加密存储敏感信息
CREATE TABLE external_integrations (
    integration_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_name VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'Stripe_API_Keys', 'Google_OAuth_Client_IDs'
    config JSONB NOT NULL, -- 存储加密的配置数据，如API密钥、Client ID/Secret等
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 文件存储表 (Files)
-- 用于存储用户上传的图片、视频等文件信息，实际文件存储在对象存储中
CREATE TABLE files (
    file_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50) NOT NULL, -- e.g., 'image/png', 'video/mp4'
    file_size_bytes BIGINT NOT NULL,
    storage_path TEXT NOT NULL, -- S3/GCS路径或CDN URL
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 评论/反馈表 (Feedback)
-- 用于收集用户反馈和建议
CREATE TABLE feedback (
    feedback_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID, -- 可选，如果用户未登录
    feedback_type VARCHAR(50) NOT NULL, -- 'bug_report', 'feature_request', 'general_feedback'
    subject VARCHAR(255),
    message TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'new' NOT NULL, -- 'new', 'in_progress', 'resolved', 'closed'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 订阅计划表 (Subscription_Plans)
-- 存储不同的订阅计划信息 (Free, Pro Monthly, Pro Yearly)
CREATE TABLE subscription_plans (
    plan_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_name VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'Free', 'Pro Monthly', 'Pro Yearly'
    description TEXT,
    price NUMERIC(10, 2) NOT NULL, -- 价格，对于Free计划为0
    currency CHAR(3) NOT NULL, -- 货币
    duration_months INT, -- 订阅时长，例如月付为1，年付为12，Free为NULL
    features JSONB, -- 存储该计划包含的功能列表
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 用户订阅表 (User_Subscriptions)
-- 记录用户的当前订阅状态
CREATE TABLE user_subscriptions (
    subscription_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    plan_id UUID NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active' NOT NULL, -- 'active', 'cancelled', 'expired'
    auto_renew BOOLEAN DEFAULT FALSE NOT NULL,
    last_payment_id UUID, -- 关联到最近一次支付记录
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (plan_id) REFERENCES subscription_plans(plan_id) ON DELETE RESTRICT,
    FOREIGN KEY (last_payment_id) REFERENCES payments(payment_id) ON DELETE SET NULL
);

-- 索引: 优化用户订阅查找
CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions (user_id);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions (status);

-- SEO设置表 (SEO_Settings)
-- 存储每个主页的SEO相关设置，如标题、描述、关键词等
-- 考虑到user_pages表已经有page_description和seo_keywords，此表可以用于更细粒度的SEO配置或全局SEO配置
-- 如果user_pages表已足够，此表可省略
/*
CREATE TABLE seo_settings (
    page_id UUID PRIMARY KEY,
    meta_title VARCHAR(255),
    meta_description TEXT,
    meta_keywords TEXT,
    og_title VARCHAR(255),
    og_description TEXT,
    og_image_url VARCHAR(255),
    twitter_card_type VARCHAR(50),
    twitter_site VARCHAR(255),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (page_id) REFERENCES user_pages(page_id) ON DELETE CASCADE
);
*/

-- 域名绑定表 (Custom_Domains)
-- 存储用户绑定的自定义域名信息
CREATE TABLE custom_domains (
    domain_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    page_id UUID NOT NULL,
    domain_name VARCHAR(255) UNIQUE NOT NULL,
    cname_target VARCHAR(255), -- CNAME记录的目标地址
    verification_status VARCHAR(20) DEFAULT 'pending' NOT NULL, -- 'pending', 'verified', 'failed'
    is_active BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (page_id) REFERENCES user_pages(page_id) ON DELETE CASCADE
);

-- 索引: 优化域名查找
CREATE INDEX idx_custom_domains_user_id ON custom_domains (user_id);
CREATE INDEX idx_custom_domains_page_id ON custom_domains (page_id);

-- 消息通知表 (Notifications)
-- 用于存储站内消息通知
CREATE TABLE notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'system', 'account', 'billing', 'module_update'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 索引: 优化通知查找
CREATE INDEX idx_notifications_user_id_created_at ON notifications (user_id, created_at DESC);

-- 用户设置表 (User_Settings)
-- 存储用户个性化设置，例如通知偏好、隐私设置等
CREATE TABLE user_settings (
    user_id UUID PRIMARY KEY,
    settings_data JSONB, -- 存储灵活的设置数据
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 访问日志表 (Access_Logs)
-- 记录所有HTTP请求，用于流量分析和问题排查
CREATE TABLE access_logs (
    log_id BIGSERIAL PRIMARY KEY,
    request_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    request_method VARCHAR(10) NOT NULL,
    request_url TEXT NOT NULL,
    status_code INT NOT NULL,
    response_time_ms INT,
    ip_address INET,
    user_agent TEXT,
    user_id UUID, -- 如果是已登录用户
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 索引: 优化访问日志查询
CREATE INDEX idx_access_logs_request_time ON access_logs (request_time DESC);
CREATE INDEX idx_access_logs_user_id ON access_logs (user_id);

-- 错误日志表 (Error_Logs)
-- 记录系统运行时产生的错误信息
CREATE TABLE error_logs (
    log_id BIGSERIAL PRIMARY KEY,
    error_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    service_name VARCHAR(100),
    error_level VARCHAR(20) NOT NULL, -- 'info', 'warning', 'error', 'critical'
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    context JSONB, -- 错误发生时的上下文信息
    user_id UUID, -- 如果错误与特定用户相关
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 索引: 优化错误日志查询
CREATE INDEX idx_error_logs_error_time ON error_logs (error_time DESC);
CREATE INDEX idx_error_logs_service_name ON error_logs (service_name);

-- 缓存管理表 (Cache_Management)
-- 用于管理需要定期刷新的缓存数据，例如第三方API数据缓存
CREATE TABLE cache_management (
    cache_key VARCHAR(255) PRIMARY KEY,
    cache_data JSONB NOT NULL,
    last_fetched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    next_fetch_at TIMESTAMP WITH TIME ZONE,
    ttl_seconds INT, -- Time To Live in seconds
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 国际化语言表 (Languages)
-- 存储系统支持的语言列表
CREATE TABLE languages (
    lang_code VARCHAR(10) PRIMARY KEY, -- e.g., 'en-US', 'zh-CN', 'ja-JP'
    lang_name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

-- 插入默认语言
INSERT INTO languages (lang_code, lang_name) VALUES
('en-US', 'English (United States)'),
('zh-CN', '简体中文');

-- 关联 i18n_texts 到 languages 表
ALTER TABLE i18n_texts ADD CONSTRAINT fk_i18n_texts_lang_code FOREIGN KEY (lang_code) REFERENCES languages(lang_code) ON DELETE RESTRICT;

-- 模块类型表 (Module_Types)
-- 存储所有支持的模块类型及其元数据
CREATE TABLE module_types (
    type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_type_name VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'link', 'github', 'rss'
    display_name VARCHAR(100) NOT NULL, -- 显示名称，用于UI
    description TEXT,
    is_pro_feature BOOLEAN DEFAULT FALSE NOT NULL, -- 是否为Pro用户专属功能
    icon_url VARCHAR(255), -- 模块图标
    config_schema JSONB, -- 模块配置的JSON Schema，用于前端表单生成和后端验证
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 插入一些示例模块类型
INSERT INTO module_types (module_type_name, display_name, description, is_pro_feature, icon_url, config_schema) VALUES
('link', '链接', '展示一个可点击的链接', FALSE, '/icons/link.svg', '{"type": "object", "properties": {"url": {"type": "string", "format": "url"}, "title": {"type": "string"}, "icon": {"type": "string"}}}'),
('text', '文本', '展示一段富文本内容', FALSE, '/icons/text.svg', '{"type": "object", "properties": {"content": {"type": "string"}}}'),
('image', '图片', '展示一张图片', FALSE, '/icons/image.svg', '{"type": "object", "properties": {"url": {"type": "string", "format": "url"}, "alt": {"type": "string"}}}'),
('github', 'GitHub', '动态展示GitHub贡献和仓库', TRUE, '/icons/github.svg', '{"type": "object", "properties": {"username": {"type": "string"}, "show_contributions": {"type": "boolean"}, "show_repos": {"type": "boolean"}}}'),
('spotify', 'Spotify', '动态展示正在听的歌曲', TRUE, '/icons/spotify.svg', '{"type": "object", "properties": {"user_id": {"type": "string"}}}'),
('rss', 'RSS', '动态展示RSS订阅内容', TRUE, '/icons/rss.svg', '{"type": "object", "properties": {"feed_url": {"type": "string", "format": "url"}}}');

-- 模块表关联到模块类型表
ALTER TABLE modules ADD CONSTRAINT fk_modules_module_type FOREIGN KEY (module_type) REFERENCES module_types(module_type_name) ON UPDATE CASCADE ON DELETE RESTRICT;

-- 支付网关配置表 (Payment_Gateway_Configs)
-- 存储不同支付网关的配置信息，如API密钥、回调URL等
CREATE TABLE payment_gateway_configs (
    gateway_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gateway_name VARCHAR(50) UNIQUE NOT NULL, -- 'Stripe', 'Alipay', 'WeChatPay'
    config_data JSONB NOT NULL, -- 存储加密的配置数据，如API Key, Secret
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 插入一些示例支付网关配置 (配置数据应加密存储)
INSERT INTO payment_gateway_configs (gateway_name, config_data, is_active) VALUES
('Stripe', '{"publishable_key": "pk_test_...", "secret_key": "sk_test_..."}', TRUE),
('Alipay', '{"app_id": "...", "private_key": "..."}', TRUE),
('WeChatPay', '{"mch_id": "...", "api_key": "..."}', TRUE);

-- 支付交易表关联到支付网关配置表
ALTER TABLE payments ADD CONSTRAINT fk_payments_gateway FOREIGN KEY (payment_gateway) REFERENCES payment_gateway_configs(gateway_name) ON UPDATE CASCADE ON DELETE RESTRICT;

-- 用户反馈附件表 (Feedback_Attachments)
-- 存储用户反馈的附件信息
CREATE TABLE feedback_attachments (
    attachment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feedback_id UUID NOT NULL,
    file_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (feedback_id) REFERENCES feedback(feedback_id) ON DELETE CASCADE,
    FOREIGN KEY (file_id) REFERENCES files(file_id) ON DELETE CASCADE
);

-- 用户授权表 (User_Authorizations)
-- 存储用户对特定功能的授权信息，例如某个Pro功能的使用权限
-- 替代 is_pro_user 字段，提供更细粒度的权限控制
CREATE TABLE user_authorizations (
    auth_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    feature_name VARCHAR(100) NOT NULL, -- 例如 'custom_css', 'advanced_analytics', 'custom_domain'
    is_authorized BOOLEAN DEFAULT FALSE NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE (user_id, feature_name),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 插入一些默认授权 (例如，Pro用户获得所有Pro功能授权)
-- 这需要在用户升级为Pro时，由后端逻辑插入相应的授权记录

-- 示例数据 (可选，用于测试)
-- INSERT INTO users (username, email, password_hash) VALUES ('testuser', 'test@example.com', 'hashed_password');
-- INSERT INTO templates (template_name, is_official, template_data) VALUES ('Default Template', TRUE, '{"modules": [], "appearance": {}}');
-- INSERT INTO user_pages (user_id, page_slug, template_id) VALUES ((SELECT user_id FROM users WHERE username = 'testuser'), 'testpage', (SELECT template_id FROM templates WHERE template_name = 'Default Template'));


