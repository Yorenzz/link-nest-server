-- SQL Schema for LinkDeck (PostgreSQL)

-- 用户表 (Users)
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    auth_provider VARCHAR(50) DEFAULT 'email_password' NOT NULL, -- 'email_password', 'github', 'google', 'wechat'
    is_pro_user BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 索引: 优化登录和查找
CREATE INDEX idx_users_username ON users (username);
CREATE INDEX idx_users_email ON users (email);

-- 模板表 (Templates)
-- 存储官方模板和用户自定义模板
CREATE TABLE templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_name VARCHAR(255) NOT NULL,
    template_description TEXT,
    is_official BOOLEAN DEFAULT FALSE NOT NULL, -- 是否为官方模板
    creator_user_id UUID, -- 如果是用户创建的模板，关联到用户ID
    preview_image_url VARCHAR(255), -- 模板预览图
    template_data JSONB NOT NULL, -- 存储模板的结构化数据，如模块列表、默认配置等
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (creator_user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 索引: 优化模板查找
CREATE INDEX idx_templates_is_official ON templates (is_official);

-- 用户主页表 (User_Pages)
-- 每个用户可以有多个主页，但通常只有一个活跃主页
CREATE TABLE user_pages (
    page_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    page_slug VARCHAR(100) UNIQUE NOT NULL, -- 用于生成 linkdeck.com/username 或 custom_domain/slug
    page_title VARCHAR(255) DEFAULT '我的主页' NOT NULL,
    page_description TEXT, -- 用于SEO
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

-- 模块表 (Modules)
-- 存储用户主页上的所有模块实例，例如链接模块、GitHub模块等
CREATE TABLE modules (
    module_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id UUID NOT NULL,
    module_type VARCHAR(50) NOT NULL, -- 例如 'link', 'github', 'rss', 'spotify', 'text', 'image', 'video'
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
    background_value VARCHAR(255), -- 颜色值、渐变CSS、图片URL
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
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    subscription_plan VARCHAR(50) NOT NULL, -- 'Pro_Monthly', 'Pro_Yearly'
    amount NUMERIC(10, 2) NOT NULL, -- 支付金额
    currency CHAR(3) NOT NULL, -- 货币代码 (e.g., 'USD', 'CNY')
    payment_gateway VARCHAR(50) NOT NULL, -- 'Stripe', 'Alipay', 'WeChatPay'
    transaction_id VARCHAR(255) UNIQUE NOT NULL, -- 支付网关返回的交易ID
    status VARCHAR(20) NOT NULL, -- 'pending', 'completed', 'failed', 'refunded'
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 索引: 优化支付记录查找
CREATE INDEX idx_payments_user_id ON payments (user_id);
CREATE INDEX idx_payments_transaction_id ON payments (transaction_id);

-- 社交账号绑定表 (Social_Accounts)
-- 存储用户绑定的第三方社交账号信息，用于动态模块数据拉取和授权登录
-- 考虑敏感信息加密存储
CREATE TABLE social_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    theme_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    theme_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_official BOOLEAN DEFAULT FALSE NOT NULL,
    creator_user_id UUID, -- 如果是用户贡献的主题
    preview_image_url VARCHAR(255), -- 主题预览图
    theme_data JSONB NOT NULL, -- 存储主题的样式配置（颜色、字体、布局等）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME BONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (creator_user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 索引: 优化主题查找
CREATE INDEX idx_themes_is_official ON themes (is_official);

-- 模板分类表 (Template_Categories)
-- 用于对模板进行分类，方便用户查找
CREATE TABLE categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    timestamp_utc TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- 国际化文本资源表 (I18n_Texts)
-- 存储所有需要国际化的文本内容，按语言和键值对存储
-- 适用于需要动态加载或管理多语言文本的场景
-- 如果所有文本都硬编码在前端，则此表可能不需要
CREATE TABLE i18n_texts (
    text_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lang_code VARCHAR(10) NOT NULL, -- e.g., 'en-US', 'zh-CN'
    key_name VARCHAR(255) NOT NULL, -- 文本内容的唯一键
    text_content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT SymmetricEncryption(key_name, 'text_content'),
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
    task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
-- 存储第三方API的配置，例如API密钥、回调URL等，需要加密存储敏感信息
-- 适用于需要平台级配置而非用户级配置的集成
CREATE TABLE external_integrations (
    integration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_name VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'Stripe_API_Keys', 'Google_OAuth_Client_IDs'
    config JSONB NOT NULL, -- 存储加密的配置数据，如API密钥、Client ID/Secret等
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 文件存储表 (Files)
-- 用于存储用户上传的图片、视频等文件信息，实际文件存储在对象存储中
CREATE TABLE files (
    file_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50) NOT NULL, -- e.g., 'image/png', 'video/mp4'
    file_size_bytes BIGINT NOT NULL,
    storage_path TEXT NOT NULL, -- S3/GCS路径或CDN URL
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 审计日志表 (Audit_Logs) - 补充细节
ALTER TABLE `audit_logs` ADD COLUMN `user_agent` TEXT;
ALTER TABLE `audit_logs` ADD COLUMN `request_ip` INET;
ALTER TABLE `audit_logs` ADD COLUMN `request_details` JSONB;

-- 支付交易表 (Payments) - 补充细节
ALTER TABLE `payments` ADD COLUMN `payment_method_details` JSONB;
ALTER TABLE `payments` ADD COLUMN `subscription_start_date` TIMESTAMP WITH TIME ZONE;
ALTER TABLE `payments` ADD COLUMN `subscription_end_date` TIMESTAMP WITH TIME ZONE;

-- 用户表 (Users) - 补充细节
ALTER TABLE `users` ADD COLUMN `last_login_at` TIMESTAMP WITH TIME ZONE;
ALTER TABLE `users` ADD COLUMN `profile_picture_url` VARCHAR(255);
ALTER TABLE `users` ADD COLUMN `preferred_language` VARCHAR(10) DEFAULT 'en-US';

-- 模块表 (Modules) - 补充细节
ALTER TABLE `modules` ADD COLUMN `module_title` VARCHAR(255); -- 模块的标题，例如链接模块的标题
ALTER TABLE `modules` ADD COLUMN `module_icon_url` VARCHAR(255); -- 模块的图标URL

-- 模板表 (Templates) - 补充细节
ALTER TABLE `templates` ADD COLUMN `is_public` BOOLEAN DEFAULT FALSE; -- 模板是否公开可见

-- 用户主页表 (User_Pages) - 补充细节
ALTER TABLE `user_pages` ADD COLUMN `seo_keywords` TEXT; -- SEO关键词
ALTER TABLE `user_pages` ADD COLUMN `social_share_image_url` VARCHAR(255); -- 社交分享图片

-- 评论/反馈表 (Feedback) - 考虑用户反馈功能
CREATE TABLE feedback (
    feedback_id UUID PRIMARY System.out.println(
