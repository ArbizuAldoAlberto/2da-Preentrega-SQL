-- Uso de la base de datos
USE GestionInventariosEcommerce;

-- Inserción de datos de ejemplo
-- Categorías
INSERT INTO Categoria (ID_Categoria, Nombre_Categoria, Descripción) VALUES
(1, 'Electrónica', 'Productos electrónicos y gadgets'),
(2, 'Ropa', 'Prendas de vestir y accesorios'),
(3, 'Hogar', 'Artículos para el hogar');

-- Proveedores
INSERT INTO Proveedor (ID_Proveedor, Nombre_Proveedor, Contacto) VALUES
(1, 'TechSupply', 'contacto@techsupply.com'),
(2, 'FashionWholesale', 'info@fashionwholesale.com'),
(3, 'HomeGoods', 'ventas@homegoods.com');

-- Productos
INSERT INTO Producto (ID_Producto, Nombre_Producto, Descripción, Precio, Stock, ID_Categoria, ID_Proveedor) VALUES
(1, 'Smartphone X', 'Último modelo de smartphone', 799.99, 50, 1, 1),
(2, 'Camiseta Básica', 'Camiseta de algodón', 19.99, 100, 2, 2),
(3, 'Lámpara LED', 'Lámpara de escritorio LED', 39.99, 30, 3, 3);

-- Clientes
INSERT INTO Cliente (ID_Cliente, Nombre_Cliente, Correo_Electronico, Direccion) VALUES
(1, 'Juan Pérez', 'juan@email.com', 'Calle Principal 123'),
(2, 'María García', 'maria@email.com', 'Avenida Central 456');

-- Pedidos
INSERT INTO Pedido (ID_Pedido, Fecha_Pedido, ID_Cliente) VALUES
(1, '2024-06-15', 1),
(2, '2024-06-16', 2);

-- Detalles de Pedido
INSERT INTO Detalle_Pedido (ID_Detalle, ID_Pedido, ID_Producto, Cantidad, Precio_Unitario) VALUES
(1, 1, 1, 1, 799.99),
(2, 1, 2, 2, 19.99),
(3, 2, 3, 1, 39.99);

-- Vistas
CREATE VIEW vw_productos_disponibles AS
SELECT p.ID_Producto, p.Nombre_Producto, p.Precio, p.Stock, c.Nombre_Categoria
FROM Producto p
JOIN Categoria c ON p.ID_Categoria = c.ID_Categoria
WHERE p.Stock > 0;

CREATE VIEW vw_resumen_pedidos AS
SELECT p.ID_Pedido, p.Fecha_Pedido, c.Nombre_Cliente, 
       SUM(dp.Cantidad * dp.Precio_Unitario) AS Total_Pedido
FROM Pedido p
JOIN Cliente c ON p.ID_Cliente = c.ID_Cliente
JOIN Detalle_Pedido dp ON p.ID_Pedido = dp.ID_Pedido
GROUP BY p.ID_Pedido, p.Fecha_Pedido, c.Nombre_Cliente;

CREATE VIEW vw_productos_por_proveedor AS
SELECT pr.ID_Proveedor, pr.Nombre_Proveedor, p.ID_Producto, p.Nombre_Producto, p.Stock
FROM Proveedor pr
JOIN Producto p ON pr.ID_Proveedor = p.ID_Proveedor;

-- Funciones
DELIMITER //
CREATE FUNCTION fn_calcular_total_pedido(pedido_id INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(10,2);
    SELECT SUM(Cantidad * Precio_Unitario) INTO total
    FROM Detalle_Pedido
    WHERE ID_Pedido = pedido_id;
    RETURN COALESCE(total, 0);
END //

CREATE FUNCTION fn_obtener_stock_producto(producto_id INT) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE stock_actual INT;
    SELECT Stock INTO stock_actual
    FROM Producto
    WHERE ID_Producto = producto_id;
    RETURN COALESCE(stock_actual, 0);
END //

CREATE FUNCTION fn_calcular_valor_inventario()
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE valor_total DECIMAL(10,2);
    SELECT SUM(Precio * Stock) INTO valor_total
    FROM Producto;
    RETURN COALESCE(valor_total, 0);
END //
DELIMITER ;

-- Stored Procedures
DELIMITER //
CREATE PROCEDURE sp_actualizar_stock(IN producto_id INT, IN cantidad INT)
BEGIN
    UPDATE Producto
    SET Stock = Stock - cantidad
    WHERE ID_Producto = producto_id;
END //

CREATE PROCEDURE sp_crear_pedido(
    IN cliente_id INT,
    IN producto_id INT,
    IN cantidad INT,
    OUT nuevo_pedido_id INT
)
BEGIN
    DECLARE precio_producto DECIMAL(10,2);
    
    START TRANSACTION;
    
    -- Crear nuevo pedido
    INSERT INTO Pedido (Fecha_Pedido, ID_Cliente) VALUES (CURDATE(), cliente_id);
    SET nuevo_pedido_id = LAST_INSERT_ID();
    
    -- Obtener precio del producto
    SELECT Precio INTO precio_producto FROM Producto WHERE ID_Producto = producto_id;
    
    -- Agregar detalle del pedido
    INSERT INTO Detalle_Pedido (ID_Pedido, ID_Producto, Cantidad, Precio_Unitario)
    VALUES (nuevo_pedido_id, producto_id, cantidad, precio_producto);
    
    -- Actualizar stock
    CALL sp_actualizar_stock(producto_id, cantidad);
    
    COMMIT;
END //

CREATE PROCEDURE sp_reporte_ventas_por_categoria(IN fecha_inicio DATE, IN fecha_fin DATE)
BEGIN
    SELECT c.Nombre_Categoria, SUM(dp.Cantidad * dp.Precio_Unitario) AS Total_Ventas
    FROM Categoria c
    JOIN Producto p ON c.ID_Categoria = p.ID_Categoria
    JOIN Detalle_Pedido dp ON p.ID_Producto = dp.ID_Producto
    JOIN Pedido ped ON dp.ID_Pedido = ped.ID_Pedido
    WHERE ped.Fecha_Pedido BETWEEN fecha_inicio AND fecha_fin
    GROUP BY c.Nombre_Categoria
    ORDER BY Total_Ventas DESC;
END //
DELIMITER ;

-- Triggers
DELIMITER //
CREATE TRIGGER tr_actualizar_stock_despues_pedido
AFTER INSERT ON Detalle_Pedido
FOR EACH ROW
BEGIN
    UPDATE Producto
    SET Stock = Stock - NEW.Cantidad
    WHERE ID_Producto = NEW.ID_Producto;
END //

CREATE TRIGGER tr_verificar_stock_antes_pedido
BEFORE INSERT ON Detalle_Pedido
FOR EACH ROW
BEGIN
    DECLARE stock_disponible INT;
    SELECT Stock INTO stock_disponible
    FROM Producto
    WHERE ID_Producto = NEW.ID_Producto;
    
    IF stock_disponible < NEW.Cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente para completar el pedido';
    END IF;
END //
DELIMITER ;
