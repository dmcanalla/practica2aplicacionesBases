DROP TABLE detalle_pedido CASCADE CONSTRAINTS;
DROP TABLE pedidos CASCADE CONSTRAINTS;
DROP TABLE platos CASCADE CONSTRAINTS;
DROP TABLE personal_servicio CASCADE CONSTRAINTS;
DROP TABLE clientes CASCADE CONSTRAINTS;


DROP SEQUENCE seq_pedidos;


-- Creación de tablas y secuencias



create sequence seq_pedidos;

CREATE TABLE clientes (
    id_cliente INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    telefono VARCHAR2(20)
);

CREATE TABLE personal_servicio (
    id_personal INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    pedidos_activos INTEGER DEFAULT 0 CHECK (pedidos_activos <= 5)
);

CREATE TABLE platos (
    id_plato INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponible INTEGER DEFAULT 1 CHECK (DISPONIBLE in (0,1))
);

CREATE TABLE pedidos (
    id_pedido INTEGER PRIMARY KEY,
    id_cliente INTEGER REFERENCES clientes(id_cliente),
    id_personal INTEGER REFERENCES personal_servicio(id_personal),
    fecha_pedido DATE DEFAULT SYSDATE,
    total DECIMAL(10, 2) DEFAULT 0
);

CREATE TABLE detalle_pedido (
    id_pedido INTEGER REFERENCES pedidos(id_pedido),
    id_plato INTEGER REFERENCES platos(id_plato),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (id_pedido, id_plato)
);


	
-- Procedimiento a implementar para realizar la reserva
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 
 -- se supone que antes del begin hay que fabricarse los posibles errores
 -- supongo que por asignación, hay que hacer := 
    err_pedido_inexistente constant char := 'no existe el plato seleccionado';
    err_personal_ocupado constant char := 'personal seleccionado ocupado en estos momentos';
    err_no_plato_seleccionado constant char := 'el pedido debe tener al menos un plato';
    err_max_pedidos constant char := 'el personal de servicios tiene demasiados pedidos';
    err_primero_inexistente constant char := 'primer plato seleccionado no existe';
    err_segundo_inexistente constant char  := 'segundo plato seleccionado no existe';
    err_plato_no_disponible constant char := 'alguno de los platos no está disponible';
    
    CURSOR c_plato1 IS
        SELECT ID_PLATO ,
                PRECIO ,
                DISPONIBLE
        FROM platos
        WHERE id_plato = arg_id_primer_plato;
    CURSOR c_plato2 IS
        SELECT ID_PLATO ,
                PRECIO ,
                DISPONIBLE
        FROM platos
        WHERE id_plato = arg_id_segundo_plato;
begin
    -- Bloquear la tabla en modo exclusivo
    LOCK TABLE personal_servicio IN EXCLUSIVE MODE;
    LOCK TABLE platos IN EXCLUSIVE MODE;
    -- compruebo las excepciones del primero y segundo
    if arg_id_primer_plato is null and arg_id_segundo_plato is null then
        raise_application_error(-20002, err_no_plato_seleccionado);
    end if;
    
    OPEN c_plato1;
    OPEN c_plato2;
    if arg_id_primer_plato is not null and not c_plato1%FOUND
    then
        raise_application_error(-20004, err_primero_inexistente);
    end if;

    if arg_id_segundo_plato is not null and not c_plato2%FOUND
    then
        raise_application_error(-20004, err_segundo_inexistente);
    end if;
    
    declare 
        v_plato1_id INTEGER;
        v_plato2_id INTEGER;
    
        v_plato1_precio DECIMAL(10, 2);
        v_plato2_precio DECIMAL(10, 2);
        
        v_plato1_disponible integer;
        v_plato2_disponible integer;
    begin
        fetch c_plato1 into v_plato1_id, v_plato1_precio, v_plato1_disponible;
        fetch c_plato2 into v_plato2_id, v_plato2_precio, v_plato2_disponible;
    
        if v_plato1_disponible = 0 or v_plato2_disponible = 0 then
            raise_application_error(-20001, err_plato_no_disponible);
        end if;
    end;
    CLOSE c_plato1;
    CLOSE c_plato2;
    
    declare 
    v_pedidos_activos integer (10);
    begin
        select pedidos_activos 
        into v_pedidos_activos 
        from personal_servicio
        where id_personal = arg_id_personal;
        if v_pedidos_activos >= 5 then
            raise_application_error(-20003, err_max_pedidos);
        end if;
    end;

    --calculo el total
    declare
        precio_total int;
    begin 
        SELECT SUM(precio)
        INTO precio_total
        FROM platos
        WHERE id_plato IN (arg_id_primer_plato, arg_id_segundo_plato);
        
        insert into pedidos (id_pedido, id_cliente, id_personal, fecha_pedido, total)
        values (seq_pedidos.NEXTVAL, arg_id_cliente, arg_id_personal, CURRENT_DATE, precio_total);
    end;
    
    -- añadir pedido. 
    -- pedido depende de: personal, platos, pedido, detalles, registro
     -- actualizo la tabla de pedidos
    
    IF arg_id_primer_plato = arg_id_segundo_plato THEN
        INSERT INTO detalle_pedido 
            (id_pedido, id_plato, cantidad)
        VALUES
            (seq_pedidos.CURRVAL, arg_id_primer_plato, 2);
    ELSE
        INSERT INTO detalle_pedido
            (id_pedido, id_plato, cantidad)
        VALUES 
            (seq_pedidos.CURRVAL, arg_id_primer_plato, 1);
            
        INSERT INTO detalle_pedido
            (id_pedido, id_plato, cantidad)
        VALUES (seq_pedidos.CURRVAL, arg_id_primer_plato, 2);
    END IF;
    

    UPDATE personal_servicio SET pedidos_activos = pedidos_activos + 1
    WHERE id_personal = arg_id_personal;
    COMMIT;
 end;
/
------ Deja aquí tus respuestas a las preguntas del enunciado:
-- NO SE CORREGIRÁN RESPUESTAS QUE NO ESTÉN AQUÍ (utiliza el espacio que necesites apra cada una)
-- * P4.1 >¿Cómo garantizas en tu código que un miembro del personal de servicio no supere el lı́mite de pedidos activos?
--       if v_pedidos_activos >= 5 then
--            raise_application_error(-20003, err_max_pedidos);
--        end if;
-- * P4.2 >¿Cómo evitas que dos transacciones concurrentes asignen un pedido al mismo personal de servicio cuyos pedidos activos estan a punto de superar el lı́mite?
-->         LOCK TABLE personal_servicio IN EXCLUSIVE MODE;
--          LOCK TABLE platos IN EXCLUSIVE MODE;
-- * P4.3 >Una vez hechas las comprobaciones en los pasos 1 y 2,
--          ¿podrı́as asegurar que el pedido se puede realizar de manera correcta en el paso 4 y no se generan inconsistencias?¿Por qué?Recuerda que trabajamos en entornos con conexiones concurrentes.
--            Si porque bloquee las tablas al principio
--
-- * P4.4
--
--
-- * P4.5
-- 


create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/

-- hay que crear el archivo para los tests
create or replace procedure inicializa_test is
begin
    
    reset_seq('seq_pedidos');
        
  
    delete from Detalle_pedido;
    delete from Pedidos;
    delete from Platos;
    delete from Personal_servicio;
    delete from Clientes;
    
    -- Insertar datos de prueba
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (1, 'Pepe', 'Perez', '123456789');
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (2, 'Ana', 'Garcia', '987654321');
    
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (1, 'Carlos', 'Lopez', 0);
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (2, 'Maria', 'Fernandez', 5);
    
    insert into Platos (id_plato, nombre, precio, disponible) values (1, 'Sopa', 10.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (2, 'Pasta', 12.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (3, 'Carne', 15.0, 0);

    commit;
end;
/

exec inicializa_test;

-- Completa lost test, incluyendo al menos los del enunciado y añadiendo los que consideres necesarios

create or replace procedure test_registrar_pedido is
 begin
    
  --caso 1 Pedido correct, se realiza
  begin
    inicializa_test;
  end;
  
  -- Idem para el resto de casos

  /* - Si se realiza un pedido vac´ıo (sin platos) devuelve el error -200002.
     - Si se realiza un pedido con un plato que no existe devuelve en error -20004.
     - Si se realiza un pedido que incluye un plato que no est´a ya disponible devuelve el error -20001.
     - Personal de servicio ya tiene 5 pedidos activos y se le asigna otro pedido devuelve el error -20003
     - ... los que os puedan ocurrir que puedan ser necesarios para comprobar el correcto funcionamiento del procedimiento
*/
  
end;
/


set serveroutput on;
exec test_registrar_pedido;
