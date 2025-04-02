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
    v_plato1_id INTEGER;
    v_plato2_id INTEGER;

    v_plato1_precio DECIMAL(10, 2);
    v_plato2_precio DECIMAL(10, 2);
    
    v_plato1_disponible integer;
    v_plato2_disponible integer;
    
    v_plato1_count number;
    v_plato2_count number;
    
    --v_plato1_cantidad integer;
    --v_plato2_cantidad integer;
        
 -- se supone que antes del begin hay que fabricarse los posibles errores
 -- supongo que por asignación, hay que hacer := 
    err_pedido_inexistente constant varchar(100) := 'no existe el plato seleccionado';
    err_personal_ocupado constant varchar(100) := 'personal seleccionado ocupado en estos momentos';
    err_no_plato_seleccionado constant varchar(100) := 'el pedido debe tener al menos un plato';
    err_max_pedidos constant varchar(100) := 'el personal de servicios tiene demasiados pedidos';
    err_primero_inexistente constant varchar(100) := 'primer plato seleccionado no existe';
    err_segundo_inexistente constant varchar(100)  := 'segundo plato seleccionado no existe';
    err_plato_no_disponible constant varchar(100) := 'alguno de los platos no está disponible';
 
    begin
    
    -- Bloquear la tabla en modo exclusivo
    LOCK TABLE platos IN EXCLUSIVE MODE;
    --En la tabla personal_servicio bloqueareé luego la fila solo con un SELECT FOR UPDATE justo antes de hacer la comprobación
    
    -- compruebo la excepcion del primero y segundo null
    if arg_id_primer_plato is null and arg_id_segundo_plato is null then
        raise_application_error(-20002, err_no_plato_seleccionado);
    end if;
    
    
    if  arg_id_primer_plato is  not null
    then
        --Si no está en la tabla lanzo execpcion
        SELECT COUNT(*)
        INTO v_plato1_count
        FROM platos
        WHERE id_plato = arg_id_primer_plato;
 
        if v_plato1_count=0 then
            raise_application_error(-20004, err_primero_inexistente);
        end if;
        -----------Me meto las cosas del plato1 en mis variables, no puede fallar porque ya he comprobado que la fila está en la tabla y esta tabla está bloqueada
        select id_plato, precio, disponible 
        into v_plato1_id, v_plato1_precio, v_plato1_disponible
        from platos
        where id_plato = arg_id_primer_plato;
    end if;
    
    if ( arg_id_segundo_plato is  not null)
    then
        --Si no está en la tabla lanzo execpcion
        SELECT COUNT(*)
        INTO v_plato2_count
        FROM platos
        WHERE id_plato = arg_id_segundo_plato;
        if v_plato2_count = 0 then
            raise_application_error(-20004, err_segundo_inexistente);
        end if;
        ----------Me meto las cosas del plato2 en mis variables
        select id_plato, precio, disponible 
        into v_plato2_id, v_plato2_precio, v_plato2_disponible
        from platos
        where id_plato = arg_id_segundo_plato;
    end if;
    
    --Compruebo si están disponibles
     if v_plato1_disponible = 0 or v_plato2_disponible = 0 then
        raise_application_error(-20001, err_plato_no_disponible); --la tabla platos está bloqueada por lo que si están disponibles ahora los estarán hasta que haga commit, es como si estubiera congelada, no puede venir ningún listillo a hacer que alguno no esté disponible después de que haga la comprobación
    end if;
    
    declare 
        v_pedidos_activos integer (10);
    begin
        SELECT pedidos_activos 
        into v_pedidos_activos 
        from personal_servicio
        where id_personal = arg_id_personal
        FOR UPDATE; --Bloqueo la fila para mantener la consistencia y que esta condición sea valida hasta que hagamos commit
        
        if v_pedidos_activos >= 5 then
            raise_application_error(-20003, err_max_pedidos);
        end if;
    end;

    --calculo el total haciendo la suma
    declare
        precio_total int;
    begin 
        SELECT SUM(precio)
        INTO precio_total
        FROM platos
        WHERE id_plato IN (arg_id_primer_plato, arg_id_segundo_plato); --Aunque uno de ellos sea null funcionará bien el IN, y la comprobación de que ambos no son null ya fue hecha
        
        insert into pedidos (id_pedido, id_cliente, id_personal, fecha_pedido, total)
        values (seq_pedidos.NEXTVAL, arg_id_cliente, arg_id_personal, CURRENT_DATE, precio_total);
    end;
    
    -- añadir pedido. 
    -- pedido depende de: personal, platos, pedido, detalles, registro
     -- actualizo la tabla de pedidos
    
    IF arg_id_primer_plato = arg_id_segundo_plato THEN --La comprobacion de si ambos son null ya ha sido hecha más arriba
        INSERT INTO detalle_pedido 
            (id_pedido, id_plato, cantidad)
        VALUES
            (seq_pedidos.CURRVAL, arg_id_primer_plato, 2);
    ELSE
        IF arg_id_primer_plato is not null then
            INSERT INTO detalle_pedido
                (id_pedido, id_plato, cantidad)
            VALUES 
                (seq_pedidos.CURRVAL, arg_id_primer_plato, 1);
        END IF;
        
        IF arg_id_segundo_plato is not null then
            INSERT INTO detalle_pedido
                (id_pedido, id_plato, cantidad)
            VALUES (seq_pedidos.CURRVAL, arg_id_segundo_plato, 1);
        END IF;
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
--        SELECT pedidos_activos 
 --       into v_pedidos_activos 
 --       from personal_servicio
 --       where id_personal = arg_id_personal
  --      FOR UPDATE;
  -- Este for update bloqueará esta fila hasta que hagamos commit entonces es imposible que 2 transaciones sumen 1 a la vez, la primera que lea la fila la bloqueara y la otra no podrá ni leer ni escribir,
  -- si despues de que la primera haga commit(aquí se libera el bloqueo) los pedidos activos son 5 la segunda transacción no seguriá adelante y lanzará excepción
--
-- * P4.3 >Una vez hechas las comprobaciones en los pasos 1 y 2,
--          ¿podrı́as asegurar que el pedido se puede realizar de manera correcta en el paso 4 y no se generan inconsistencias?¿Por qué?Recuerda que trabajamos en entornos con conexiones concurrentes.
--            
--          -Si porque para la tabla platos la bloquee entera al principio con   LOCK TABLE platos IN EXCLUSIVE MODE;
--             Y la tabla personal_servicio la bloqueo justo antes de hacer la comprobación con FOR UPDATE;
--
-- * P4.4 >Si modificásemos la tabla de personal servicio añadien-
--      do CHECK (pedido activos ≤ 5), ¿Qué implicaciones tendrı́a en
--      tu código? 
--          
--      -La comprobación la haría la base de datos de manera automática y no tendriamos que comprobarla manualmente.


--      >¿Cómo afectarı́a en la gestión de excepciones? Describe en detalle las modificaciones que deberı́as hacer en tu código
--      para mejorar tu solución ante esta situación (puedes añadir pseudocódigo).
--          
--      -Deberiamos añadir un bloque excepciones para capturar la exceción violación de check y lanzar una excepción nuestra, en este caso la -20003
--                (Sería como convertir la exceción de violacion de check en una excecpicion nuestra)
--
--
-- * P4.5 >Qué tipo de estrategia de programación has utilizado? ¿Cómo puede verse en tu código?
--         -He utiliazado una estrategia defensiva, Esto puede verse en que siempre hago primero las compribaciones y luego ya hago las operaciones en la base de datos.
--          Hago las comprobaciones con ifs y si no se compulen lanzo excepciones y no hago las operaciones. Por ejemplo los SELECT COUNT(*) comprueban que la fila está en la tabla
--          Si hubiera hecho una estrategia defensiva me habria puesto ha hacer operaciones directamente y luego en un bloque de excepciones ver si algo a salido mal y hacer algo al respecto.
--          mi codigo no tiene bloques de excepciones porque siempre antes de hacer nada comprueba que todo este bien y no va a dar error 


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
    -- se hace el pedido, entonces imprimimos que se ha hecho bien , va a tener primero y segundo
        dbms_output.put_line('comenzando test 1, prueba de pedido correctamente');
        registrar_pedido(2,1,1,1);
        dbms_output.put_line('Test 1 , pedido correctamente realizado');
    declare 
    registro_num_pedido int;
    -- verifico que efectivamente se cumple el test
    begin
         select count(*) 
         into registro_num_pedido 
         from pedidos
         where id_cliente=2 and id_personal = 1 ;
         
    -- condicional de que se cumple, un pedido, entonces 1
         if (registro_num_pedido = 1)
         then
          dbms_output.put_line('test 1, correcto , pedido realizado y cargado en base de datos');
          else
         dbms_output.put_line('test 1 incorrecto, el pedido no se ha guardado en base de datos');
         end if;
    end;
    exception when others 
    then
    dbms_output.put_line('ERR '|| SQLERRM);
    end;
  
  -- Idem para el resto de casos

   -- Si se realiza un pedido vacio (sin platos) devuelve el error -200002.
  begin 
  inicializa_test;
    dbms_output.put_line('comenzando test 2, prueba de pedido erroneo sin platos');
    registrar_pedido(2,1,null,null);
    dbms_output.put_line('test 2 , la tarea no fallo con exito, revisar excepcion de platos');
    exception when others then
     if (SQLCODE = -20002) 
     then
     dbms_output.put_line('test 2  OK, la tarea fallo con exito' || SQLCODE );
     else
      dbms_output.put_line('test 2  NOT OK, la tarea fallo pero se esperaba -20002, no ' || SQLCODE );
      end if;
  end;
     -- Si se realiza un pedido con un plato que no existe devuelve en error -20004.
     begin 
  inicializa_test;
     dbms_output.put_line('comenzando test 3, prueba de pedido erroneo, plato inexistente');
    registrar_pedido(1,1,346,1);
    dbms_output.put_line('test 3 , la tarea no fallo con exito, revisar excepcion de platos');
    
    exception when others then
     if (SQLCODE = -20004) 
     then
     dbms_output.put_line('test 3  OK, la tarea fallo con exito' || SQLCODE );
     else
      dbms_output.put_line('test 3  NOT OK, la tarea fallo pero se esperaba -20004, no ' || SQLCODE );
      end if;
  end;
  
     -- Si se realiza un pedido que incluye un plato que no est´a ya disponible devuelve el error -20001.
     begin 
  inicializa_test;
       dbms_output.put_line('comenzando test 4, prueba de pedido erroneo plato no disponible');
       registrar_pedido(1,1,3,1);
     dbms_output.put_line('test 2 , la tarea no fallo con exito, revisar excepcion de platos');
    
        exception when others then
      if (SQLCODE = -20001) 
     then
     dbms_output.put_line('test 4  OK, la tarea fallo con exito' || SQLCODE );
     else
      dbms_output.put_line('test 4  NOT OK, la tarea fallo pero se esperaba -20001, no ' || SQLCODE );
      end if;
   end;
   
    -- Personal de servicio ya tiene 5 pedidos activos y se le asigna otro pedido devuelve el error -20003
    begin 
    inicializa_test;
    dbms_output.put_line('comenzando test 5, prueba de pedido erroneo camarero/a no disponible');
    registrar_pedido(1,2,1,null);
    
    dbms_output.put_line('test 5 , la tarea no fallo con exito, revisar excepcion camareros');
    
    exception when others then
     if (SQLCODE = -20003) 
     then
        dbms_output.put_line('test 5  OK, la tarea fallo con exito' || SQLCODE );
     else
        dbms_output.put_line('test 5  NOT OK, la tarea fallo pero se esperaba -20003, no ' || SQLCODE );
      end if;
  end;
     -- ... los que os puedan ocurrir que puedan ser necesarios para comprobar el correcto funcionamiento del procedimiento
     
end;
/


set serveroutput on;
exec test_registrar_pedido;
