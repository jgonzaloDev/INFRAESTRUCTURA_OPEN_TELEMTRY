-- ============================================================
-- Seeds - Datos Iniciales para Proyecto Multimodulo
-- Módulos: Customers y Orders
-- ============================================================

PRINT '🌱 Iniciando seeds de datos...'
PRINT ''

-- ============================================================
-- CUSTOMERS - Datos de ejemplo
-- ============================================================

PRINT '👥 Insertando customers...'

-- Customer 1: Acme Corporation
IF NOT EXISTS (SELECT * FROM [dbo].[customers] WHERE customer_code = 'CUST001')
BEGIN
    INSERT INTO [dbo].[customers] 
    (customer_code, name, email, phone, address, city, country, status, created_at, updated_at)
    VALUES 
    ('CUST001', 'Acme Corporation', 'contact@acme.com', '+1-555-0101', '123 Business St', 'New York', 'USA', 'ACTIVE', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Customer: Acme Corporation'
END
ELSE
BEGIN
    PRINT '   ℹ️  Customer CUST001 ya existe'
END

-- Customer 2: Tech Solutions Ltd
IF NOT EXISTS (SELECT * FROM [dbo].[customers] WHERE customer_code = 'CUST002')
BEGIN
    INSERT INTO [dbo].[customers] 
    (customer_code, name, email, phone, address, city, country, status, created_at, updated_at)
    VALUES 
    ('CUST002', 'Tech Solutions Ltd', 'info@techsolutions.com', '+44-20-1234-5678', '456 Innovation Ave', 'London', 'UK', 'ACTIVE', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Customer: Tech Solutions Ltd'
END
ELSE
BEGIN
    PRINT '   ℹ️  Customer CUST002 ya existe'
END

-- Customer 3: Global Traders Inc
IF NOT EXISTS (SELECT * FROM [dbo].[customers] WHERE customer_code = 'CUST003')
BEGIN
    INSERT INTO [dbo].[customers] 
    (customer_code, name, email, phone, address, city, country, status, created_at, updated_at)
    VALUES 
    ('CUST003', 'Global Traders Inc', 'sales@globaltraders.com', '+1-555-0202', '789 Commerce Blvd', 'Los Angeles', 'USA', 'ACTIVE', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Customer: Global Traders Inc'
END
ELSE
BEGIN
    PRINT '   ℹ️  Customer CUST003 ya existe'
END

-- Customer 4: Innovation Hub
IF NOT EXISTS (SELECT * FROM [dbo].[customers] WHERE customer_code = 'CUST004')
BEGIN
    INSERT INTO [dbo].[customers] 
    (customer_code, name, email, phone, address, city, country, status, created_at, updated_at)
    VALUES 
    ('CUST004', 'Innovation Hub', 'contact@innovationhub.com', '+49-30-1234-5678', '321 Tech Park', 'Berlin', 'Germany', 'ACTIVE', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Customer: Innovation Hub'
END
ELSE
BEGIN
    PRINT '   ℹ️  Customer CUST004 ya existe'
END

-- Customer 5: Digital Commerce Co
IF NOT EXISTS (SELECT * FROM [dbo].[customers] WHERE customer_code = 'CUST005')
BEGIN
    INSERT INTO [dbo].[customers] 
    (customer_code, name, email, phone, address, city, country, status, created_at, updated_at)
    VALUES 
    ('CUST005', 'Digital Commerce Co', 'hello@digitalcommerce.com', '+81-3-1234-5678', '555 Digital Street', 'Tokyo', 'Japan', 'ACTIVE', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Customer: Digital Commerce Co'
END
ELSE
BEGIN
    PRINT '   ℹ️  Customer CUST005 ya existe'
END

GO

-- ============================================================
-- ORDERS - Datos de ejemplo
-- ============================================================

PRINT ''
PRINT '📦 Insertando orders...'

-- Declarar variables para customer IDs
DECLARE @customer1_id BIGINT, @customer2_id BIGINT, @customer3_id BIGINT

SELECT @customer1_id = id FROM [dbo].[customers] WHERE customer_code = 'CUST001'
SELECT @customer2_id = id FROM [dbo].[customers] WHERE customer_code = 'CUST002'
SELECT @customer3_id = id FROM [dbo].[customers] WHERE customer_code = 'CUST003'

-- Order 1 para Customer 1
IF NOT EXISTS (SELECT * FROM [dbo].[orders] WHERE order_number = 'ORD-2024-001')
BEGIN
    INSERT INTO [dbo].[orders] 
    (order_number, customer_id, order_date, total_amount, status, notes, created_at, updated_at)
    VALUES 
    ('ORD-2024-001', @customer1_id, DATEADD(DAY, -30, GETUTCDATE()), 1500.00, 'COMPLETED', 'First order - Office supplies', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Order: ORD-2024-001'
END
ELSE
BEGIN
    PRINT '   ℹ️  Order ORD-2024-001 ya existe'
END

-- Order 2 para Customer 2
IF NOT EXISTS (SELECT * FROM [dbo].[orders] WHERE order_number = 'ORD-2024-002')
BEGIN
    INSERT INTO [dbo].[orders] 
    (order_number, customer_id, order_date, total_amount, status, notes, created_at, updated_at)
    VALUES 
    ('ORD-2024-002', @customer2_id, DATEADD(DAY, -25, GETUTCDATE()), 3200.50, 'COMPLETED', 'Tech equipment order', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Order: ORD-2024-002'
END
ELSE
BEGIN
    PRINT '   ℹ️  Order ORD-2024-002 ya existe'
END

-- Order 3 para Customer 1 (segundo pedido)
IF NOT EXISTS (SELECT * FROM [dbo].[orders] WHERE order_number = 'ORD-2024-003')
BEGIN
    INSERT INTO [dbo].[orders] 
    (order_number, customer_id, order_date, total_amount, status, notes, created_at, updated_at)
    VALUES 
    ('ORD-2024-003', @customer1_id, DATEADD(DAY, -15, GETUTCDATE()), 850.75, 'SHIPPED', 'Replenishment order', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Order: ORD-2024-003'
END
ELSE
BEGIN
    PRINT '   ℹ️  Order ORD-2024-003 ya existe'
END

-- Order 4 para Customer 3
IF NOT EXISTS (SELECT * FROM [dbo].[orders] WHERE order_number = 'ORD-2024-004')
BEGIN
    INSERT INTO [dbo].[orders] 
    (order_number, customer_id, order_date, total_amount, status, notes, created_at, updated_at)
    VALUES 
    ('ORD-2024-004', @customer3_id, DATEADD(DAY, -10, GETUTCDATE()), 2100.00, 'PROCESSING', 'Bulk order - urgent', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Order: ORD-2024-004'
END
ELSE
BEGIN
    PRINT '   ℹ️  Order ORD-2024-004 ya existe'
END

-- Order 5 para Customer 2 (segundo pedido)
IF NOT EXISTS (SELECT * FROM [dbo].[orders] WHERE order_number = 'ORD-2024-005')
BEGIN
    INSERT INTO [dbo].[orders] 
    (order_number, customer_id, order_date, total_amount, status, notes, created_at, updated_at)
    VALUES 
    ('ORD-2024-005', @customer2_id, DATEADD(DAY, -5, GETUTCDATE()), 4500.00, 'PENDING', 'Large IT infrastructure order', GETUTCDATE(), GETUTCDATE())
    PRINT '   ✅ Order: ORD-2024-005'
END
ELSE
BEGIN
    PRINT '   ℹ️  Order ORD-2024-005 ya existe'
END

GO

-- ============================================================
-- ORDER ITEMS - Datos de ejemplo
-- ============================================================

PRINT ''
PRINT '📝 Insertando order items...'

-- Declarar variables para order IDs
DECLARE @order1_id BIGINT, @order2_id BIGINT, @order3_id BIGINT, @order4_id BIGINT

SELECT @order1_id = id FROM [dbo].[orders] WHERE order_number = 'ORD-2024-001'
SELECT @order2_id = id FROM [dbo].[orders] WHERE order_number = 'ORD-2024-002'
SELECT @order3_id = id FROM [dbo].[orders] WHERE order_number = 'ORD-2024-003'
SELECT @order4_id = id FROM [dbo].[orders] WHERE order_number = 'ORD-2024-004'

-- Items para Order 1
IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order1_id AND product_code = 'PROD-001')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order1_id, 'Wireless Mouse', 'PROD-001', 10, 25.00, 250.00, GETUTCDATE())
    PRINT '   ✅ Item: Wireless Mouse'
END

IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order1_id AND product_code = 'PROD-002')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order1_id, 'Mechanical Keyboard', 'PROD-002', 10, 75.00, 750.00, GETUTCDATE())
    PRINT '   ✅ Item: Mechanical Keyboard'
END

IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order1_id AND product_code = 'PROD-003')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order1_id, 'USB Hub', 'PROD-003', 20, 25.00, 500.00, GETUTCDATE())
    PRINT '   ✅ Item: USB Hub'
END

-- Items para Order 2
IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order2_id AND product_code = 'PROD-100')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order2_id, 'Laptop - Business Edition', 'PROD-100', 5, 599.90, 2999.50, GETUTCDATE())
    PRINT '   ✅ Item: Laptop - Business Edition'
END

IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order2_id AND product_code = 'PROD-101')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order2_id, 'Docking Station', 'PROD-101', 2, 100.50, 201.00, GETUTCDATE())
    PRINT '   ✅ Item: Docking Station'
END

-- Items para Order 3
IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order3_id AND product_code = 'PROD-004')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order3_id, 'Monitor 24"', 'PROD-004', 3, 199.99, 599.97, GETUTCDATE())
    PRINT '   ✅ Item: Monitor 24"'
END

IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order3_id AND product_code = 'PROD-005')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order3_id, 'Webcam HD', 'PROD-005', 5, 50.15, 250.75, GETUTCDATE())
    PRINT '   ✅ Item: Webcam HD'
END

-- Items para Order 4
IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order4_id AND product_code = 'PROD-200')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order4_id, 'Server Rack Unit', 'PROD-200', 2, 1000.00, 2000.00, GETUTCDATE())
    PRINT '   ✅ Item: Server Rack Unit'
END

IF NOT EXISTS (SELECT * FROM [dbo].[order_items] WHERE order_id = @order4_id AND product_code = 'PROD-201')
BEGIN
    INSERT INTO [dbo].[order_items] 
    (order_id, product_name, product_code, quantity, unit_price, total_price, created_at)
    VALUES 
    (@order4_id, 'Network Switch 24-port', 'PROD-201', 1, 100.00, 100.00, GETUTCDATE())
    PRINT '   ✅ Item: Network Switch 24-port'
END

GO

-- ============================================================
-- Verificar datos insertados
-- ============================================================

PRINT ''
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
PRINT '📊 Resumen de Seeds'
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

DECLARE @total_customers INT, @total_orders INT, @total_items INT

SELECT @total_customers = COUNT(*) FROM [dbo].[customers]
SELECT @total_orders = COUNT(*) FROM [dbo].[orders]
SELECT @total_items = COUNT(*) FROM [dbo].[order_items]

PRINT 'Total customers: ' + CAST(@total_customers AS NVARCHAR(10))
PRINT 'Total orders: ' + CAST(@total_orders AS NVARCHAR(10))
PRINT 'Total order items: ' + CAST(@total_items AS NVARCHAR(10))

PRINT ''
PRINT '👥 Top 5 Customers:'
SELECT TOP 5 customer_code, name, email, city, country 
FROM [dbo].[customers] 
ORDER BY id

PRINT ''
PRINT '📦 Recent Orders:'
SELECT TOP 5 order_number, order_date, total_amount, status
FROM [dbo].[orders] 
ORDER BY order_date DESC

PRINT ''
PRINT '✅ Seeds ejecutados exitosamente'
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
