-- ============================================================
-- Script de Migración - Proyecto Multimodulo
-- Creación de tablas para módulos: Customers y Orders
-- ============================================================

-- ============================================================
-- Módulo: CUSTOMERS
-- ============================================================

-- Crear tabla: customers
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'customers')
BEGIN
    CREATE TABLE [dbo].[customers](
        [id] [bigint] IDENTITY(1,1) NOT NULL,
        [customer_code] [nvarchar](20) NOT NULL,
        [name] [nvarchar](150) NOT NULL,
        [email] [nvarchar](100) NOT NULL,
        [phone] [nvarchar](20) NULL,
        [address] [nvarchar](255) NULL,
        [city] [nvarchar](100) NULL,
        [country] [nvarchar](100) NULL,
        [status] [nvarchar](20) NOT NULL DEFAULT 'ACTIVE',
        [created_at] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        [updated_at] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [PK_customers] PRIMARY KEY CLUSTERED ([id] ASC),
        CONSTRAINT [UQ_customers_customer_code] UNIQUE ([customer_code]),
        CONSTRAINT [UQ_customers_email] UNIQUE ([email])
    )
    
    PRINT '✅ Tabla customers creada exitosamente'
END
ELSE
BEGIN
    PRINT 'ℹ️  Tabla customers ya existe'
END
GO

-- Crear índices para customers
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_customers_status')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_customers_status]
    ON [dbo].[customers] ([status])
    INCLUDE ([name], [email])
    
    PRINT '✅ Índice IX_customers_status creado'
END
GO

-- ============================================================
-- Módulo: ORDERS
-- ============================================================

-- Crear tabla: orders
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'orders')
BEGIN
    CREATE TABLE [dbo].[orders](
        [id] [bigint] IDENTITY(1,1) NOT NULL,
        [order_number] [nvarchar](30) NOT NULL,
        [customer_id] [bigint] NOT NULL,
        [order_date] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        [total_amount] [decimal](18, 2) NOT NULL DEFAULT 0.00,
        [status] [nvarchar](20) NOT NULL DEFAULT 'PENDING',
        [notes] [nvarchar](500) NULL,
        [created_at] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        [updated_at] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [PK_orders] PRIMARY KEY CLUSTERED ([id] ASC),
        CONSTRAINT [UQ_orders_order_number] UNIQUE ([order_number])
    )
    
    PRINT '✅ Tabla orders creada exitosamente'
END
ELSE
BEGIN
    PRINT 'ℹ️  Tabla orders ya existe'
END
GO

-- Crear tabla: order_items
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'order_items')
BEGIN
    CREATE TABLE [dbo].[order_items](
        [id] [bigint] IDENTITY(1,1) NOT NULL,
        [order_id] [bigint] NOT NULL,
        [product_name] [nvarchar](200) NOT NULL,
        [product_code] [nvarchar](50) NOT NULL,
        [quantity] [int] NOT NULL,
        [unit_price] [decimal](18, 2) NOT NULL,
        [total_price] [decimal](18, 2) NOT NULL,
        [created_at] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [PK_order_items] PRIMARY KEY CLUSTERED ([id] ASC)
    )
    
    PRINT '✅ Tabla order_items creada exitosamente'
END
ELSE
BEGIN
    PRINT 'ℹ️  Tabla order_items ya existe'
END
GO

-- ============================================================
-- Foreign Keys
-- ============================================================

-- FK: orders -> customers
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys 
    WHERE name = 'FK_orders_customer_id' 
    AND parent_object_id = OBJECT_ID('orders')
)
BEGIN
    ALTER TABLE [dbo].[orders]
    ADD CONSTRAINT [FK_orders_customer_id]
    FOREIGN KEY ([customer_id])
    REFERENCES [dbo].[customers] ([id])
    ON DELETE CASCADE
    
    PRINT '✅ Foreign key FK_orders_customer_id creada'
END
ELSE
BEGIN
    PRINT 'ℹ️  Foreign key FK_orders_customer_id ya existe'
END
GO

-- FK: order_items -> orders
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys 
    WHERE name = 'FK_order_items_order_id' 
    AND parent_object_id = OBJECT_ID('order_items')
)
BEGIN
    ALTER TABLE [dbo].[order_items]
    ADD CONSTRAINT [FK_order_items_order_id]
    FOREIGN KEY ([order_id])
    REFERENCES [dbo].[orders] ([id])
    ON DELETE CASCADE
    
    PRINT '✅ Foreign key FK_order_items_order_id creada'
END
ELSE
BEGIN
    PRINT 'ℹ️  Foreign key FK_order_items_order_id ya existe'
END
GO

-- ============================================================
-- Crear índices adicionales para rendimiento
-- ============================================================

-- Índice para orders por customer_id
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_orders_customer_id')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_orders_customer_id]
    ON [dbo].[orders] ([customer_id])
    INCLUDE ([order_number], [order_date], [status])
    
    PRINT '✅ Índice IX_orders_customer_id creado'
END
GO

-- Índice para orders por status
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_orders_status')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_orders_status]
    ON [dbo].[orders] ([status])
    
    PRINT '✅ Índice IX_orders_status creado'
END
GO

-- Índice para order_items por order_id
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_order_items_order_id')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_order_items_order_id]
    ON [dbo].[order_items] ([order_id])
    
    PRINT '✅ Índice IX_order_items_order_id creado'
END
GO

-- ============================================================
-- Tabla de migraciones (para tracking)
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'migrations')
BEGIN
    CREATE TABLE [dbo].[migrations](
        [id] [int] IDENTITY(1,1) NOT NULL,
        [migration] [nvarchar](255) NOT NULL,
        [executed_at] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [PK_migrations] PRIMARY KEY CLUSTERED ([id] ASC)
    )
    
    PRINT '✅ Tabla migrations creada'
END
GO

-- Registrar migración
IF NOT EXISTS (SELECT * FROM [dbo].[migrations] WHERE migration = '001_create_multimodulo_tables')
BEGIN
    INSERT INTO [dbo].[migrations] (migration)
    VALUES ('001_create_multimodulo_tables')
    PRINT '✅ Migración registrada'
END
GO

-- ============================================================
-- Verificación final
-- ============================================================

PRINT ''
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
PRINT '📊 Resumen de Migración'
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 'customers' AS tabla, COUNT(*) AS registros FROM [dbo].[customers]
UNION ALL
SELECT 'orders', COUNT(*) FROM [dbo].[orders]
UNION ALL
SELECT 'order_items', COUNT(*) FROM [dbo].[order_items]
UNION ALL
SELECT 'migrations', COUNT(*) FROM [dbo].[migrations]

PRINT ''
PRINT '✅ Script de migración completado exitosamente'
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
