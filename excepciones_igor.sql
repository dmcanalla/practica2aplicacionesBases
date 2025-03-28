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
    err_pedido_inexistente const char := "no existe el plato seleccionado";
    err_personal_ocupado const char := "personal seleccionado ocupado en estos momentos";
    err_no_plato_seleccionado const char := "el pedido debe tener al menos un plato";
    err_max_pedidos const char := "el personal de servicios tiene demasiados pedidos";
    err_primero_inexistente const char := "primer plato seleccionado no existe";
    err_segundo_inexistente const char  := "segundo plato seleccionado no existe";
    err_plato_no_disponible const char := "alguno de los platos no está disponible"
    CURSOR c_plato1_disponible IS
        SELECT disponible
        FROM platos
        WHERE id_plato = arg_id_primer_plato
    CURSOR c_plato2_disponible IS
        SELECT disponible
        FROM platos
        WHERE id_plato = arg_id_segundo_plato
begin
    -- compruebo las excepciones del primero y segundo
    if arg_id_primer_plato is null and arg_id_segundo_plato is null then
        raise_application_error(-20002, err_no_plato_seleccionado);
    end if;
    OPEN c_plato1_disponible;
    OPEN c_plato2_disponible;
    if arg_id_primer_plato is not null and not c_plato1_disponible%FOUND
    then
        raise_application_error(-20004, err_primero_inexistente)
    end if;

    if arg_id_segundo_plato is not null and not c_plato2_disponible%FOUND
    then
        raise_application_error(-20004, err_segundo_inexistente)
    end if;

    fetch c_plato1_disponible into v_plato1_disponible;
    fetch c_plato2_disponible into v_plato2_disponible;

    if v_plato1_disponible = 0 or v_plato2_disponible = 0 then
        raise_application_error(-20001, err_plato_no_disponible)
    end if;
    CLOSE c_plato1_disponible;
    CLOSE c_plato2_disponible;

    SELECT pedidos_activos from personal_servicio
    into v_pedidos_acticos
    WHERE id_personal = arg_id_personal;
    if (v_pedidos_acticos >= 5) then
        raise_application_error(-20003, err_max_pedidos)
    end if;

    null; -- sustituye esta línea por tu código
end;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- NO SE CORREGIRÁN RESPUESTAS QUE NO ESTÉN AQUÍ (utiliza el espacio que necesites apra cada una)
-- * P4.1
--
-- * P4.2
--
-- * P4.3
--
-- * P4.4
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