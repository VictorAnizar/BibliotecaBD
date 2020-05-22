
CREATE TABLE AUTOR (
    id_autor       NUMBER(4)     PRIMARY KEY,
	nomA           VARCHAR2(30)  NOT NULL,
	apPA           VARCHAR2(30)  NOT NULL,
	apMA           VARCHAR2(30),
	nacionalidad   VARCHAR2(30)  NOT NULL
);


CREATE TABLE MATERIAL (
	id_mat         NUMBER(10)    PRIMARY KEY,
	ubicacion      VARCHAR2(30)  NOT NULL,
	titulo         VARCHAR2(30)  NOT NULL,
	colocacion     VARCHAR2(30)  NOT NULL,
    tipoMat        CHAR(1)       NOT NULL,
    CONSTRAINT ck_mat_tipMat CHECK (tipoMat IN ('L','T'))
);


CREATE TABLE CUENTA (
	id_mat             NUMBER(10),
	id_autor           NUMBER(4),
    CONSTRAINT fk_cue_idMat FOREIGN KEY (id_mat) REFERENCES  MATERIAL(id_mat) ON DELETE CASCADE,
    CONSTRAINT fk_cue_idAut FOREIGN KEY (id_autor) REFERENCES  AUTOR(id_autor),
    CONSTRAINT PK_CUENTA_IDMAT_IDAUTOR PRIMARY KEY (id_mat,id_autor)
);


CREATE TABLE LIBRO (
    id_mat     NUMBER(10)    PRIMARY KEY/*NOT NULL*/,----------------------CORREGIDO----------------
	numAd      NUMBER(4)     NOT NULL,--DEBE DE SER CONSTRAINT UNIQUE
	isbn       VARCHAR2(20)  NOT NULL,--DEBE DE SER CONSTRAINT UNIQUE
	edicion    VARCHAR2(30)  NOT NULL,
	tema       VARCHAR2(30)  NOT NULL,
    CONSTRAINT fk_lib_idMat FOREIGN KEY (id_mat) REFERENCES  MATERIAL(id_mat) ON DELETE CASCADE,
    CONSTRAINT ak_lib_isbn UNIQUE (isbn),
    CONSTRAINT ak_lib_numAd UNIQUE (numAd)
);


CREATE TABLE DIRECTOR (
	id_dir     NUMBER(4)     PRIMARY KEY/*NOT NULL*/,----------------------CORREGIDO------------------------
	nomD       VARCHAR2(30)  NOT NULL,
	apPD       CHAR(18)      NOT NULL,
	apMD       VARCHAR2(30),
	gdoAcad    VARCHAR2(30)  NOT NULL
);


CREATE TABLE TESIS (
    id_mat     NUMBER(10)  PRIMARY KEY/*NOT NULL*/,-----------------------CORREGIDO----------------------
	id_tesis   NUMBER(4),
	carrera    CHAR(18)    NOT NULL,
	anio       DATE        NOT NULL,
	id_dir     NUMBER(4),
    CONSTRAINT fk_tes_idMat FOREIGN KEY (id_mat) REFERENCES  MATERIAL(id_mat) ON DELETE CASCADE,
    CONSTRAINT fk_tes_idDir FOREIGN KEY (id_dir) REFERENCES  DIRECTOR(id_dir),
    CONSTRAINT ak_tesis_id_tesis UNIQUE (id_tesis)--LE FALTABA AGREGAR ESE CONSTRAINT
);

ALTER TABLE TESIS MODIFY carrera VARCHAR2(20);
ALTER TABLE TESIS MODIFY anio NUMBER(4);--SE CAMBIO A NUMBER PORQUE LO QUE NOS INTERESA ES EL AÑO ÚNICAMENTE Y NO LOS DÍAS O MESES 

CREATE TABLE EJEMPLAR (
	numEj      NUMBER(10)    NOT NULL,
    id_mat     NUMBER(10)    NOT NULL,
	estatus    VARCHAR2(20)  NOT NULL,--AGREGAR CONSTRAINT CHECK---------------------------------CORREGIDO----------------------
    CONSTRAINT fk_eje_idMat FOREIGN KEY (id_mat) REFERENCES  MATERIAL(id_mat) ON DELETE CASCADE,
    CONSTRAINT pk_eje_nejYidm PRIMARY KEY (numEj,id_mat),
    CONSTRAINT ck_ejemplar CHECK (estatus IN ('Disponible','En préstamo','No sale','En mantenimiento'))--LE FALTABA EL CONSTRAINT
);


CREATE TABLE TIPO_LECTOR (
	id_tipo        NUMBER(1) PRIMARY KEY/*NOT NULL*/,-----------------------------CORREGIDO-----------------------------
    tipoLector     CHAR(1)   NOT NULL,
	lim_material   NUMBER(4) NOT NULL,
	lim_dia        NUMBER(4) NOT NULL,
	lim_refrendo   NUMBER(4) NOT NULL,
    CONSTRAINT ck_tle_tipLec CHECK (tipoLector IN ('E','P','I'))
);


CREATE TABLE LECTOR (
	id_lector  NUMBER(10)      PRIMARY KEY/*NOT NULL*/,------------------------CORREGIDO-------------------
    nomL       VARCHAR2(30)    NOT NULL,
	apPL       VARCHAR2(30)    NOT NULL,
	apML       VARCHAR2(18),
	f_vig      DATE            NOT NULL,
	f_alta     DATE            NOT NULL,--SYSDATE
	telef      NUMBER(10)    NOT NULL,
	calle      VARCHAR2(30)    NOT NULL,
	colonia    VARCHAR2(18)        NOT NULL,
	numero     VARCHAR(18)        NOT NULL,
	id_tipo    NUMBER(1)       NOT NULL,
    CONSTRAINT fk_lec_idTip FOREIGN KEY (id_tipo) REFERENCES  TIPO_LECTOR(id_tipo) ON DELETE SET NULL
);


CREATE OR REPLACE PROCEDURE spAltaLector(
vID_lector IN NUMBER, vNomL IN VARCHAR2, vApPL IN VARCHAR2, vApML IN VARCHAR2, vF_alta DATE, 
vTelef IN VARCHAR2,vCalle IN VARCHAR2, vColonia IN VARCHAR2, vNumero IN VARCHAR2,vID_tipo IN NUMBER)
AS
vFecha_vig LECTOR.f_alta%TYPE;
BEGIN
vfecha_vig := ADD_MONTHS(vf_alta, 12);
INSERT INTO LECTOR VALUES(vid_lector,vNomL,vappl,vapml,vfecha_vig,vf_alta,vtelef,vcalle,vcolonia,vNumero,vid_tipo);
DBMS_OUTPUT.PUT_LINE('Lector agregado'||vNomL);
END;
/



CREATE TABLE PRESTAMO (
	--id_prestamo    NUMBER(10)  NOT NULL,
	f_inicio       DATE        NOT NULL,--HACERLOS UNICOS O UNIRLOS EN UNA PK
	f_venci        DATE        NOT NULL,
	multa          NUMBER(4)   ,--DEBERIA DE SER OPCIONAL LA MULTA
	refre_aut      NUMBER(4),
	f_devol        DATE,
    id_lector      NUMBER(10),--HACERLO UNICO
	numEj          NUMBER(10),--HACERLO UNICO
	id_mat         NUMBER(10),--HACERLO UNICO
    CONSTRAINT fk_pre_nejYidm FOREIGN KEY (numEj,id_mat) REFERENCES  EJEMPLAR (numEj,id_mat) ON DELETE CASCADE,
    CONSTRAINT fk_pre_idLec FOREIGN KEY (id_lector) REFERENCES  LECTOR (id_lector),
    CONSTRAINT pk_pre_idPre PRIMARY KEY (f_inicio,id_lector,numEj,id_mat)--AHORA SÍ LA PK DE PRESTAMO SÍ TIENE SENIDO Y ASÍ NOS CORROBORAMOS DE QUE LAS PK NO SE REPITAN
);


--TRIGGER PARA ACTUALIZAR EL ESTADO DEL EJEMPLAR DEPENDIENDO DE SI SE PRESTA O SE DEVUELVE
CREATE OR REPLACE TRIGGER tiActualizaEstado AFTER INSERT OR DELETE ON PRESTAMO
FOR EACH ROW
DECLARE
--hay que tener los datos del libro a modificar
vID_MAT NUMBER(10);
vNUMEJ NUMBER(10);
BEGIN    
    IF INSERTING THEN--SI SE INGRESA UN PRESTAMO SE TIENE QUE CAMBIAR DE "Disponible" A "En préstamo"
        --TENEMOS QUE TENER EL IDMAT Y NUMEJ DEL PRESTAMO QUE SE VA A HACER PARA DESPUES BUSCAR ESE EJEMPLAR EN LA TABLA EJEMPLAR
        UPDATE EJEMPLAR SET estatus = 'En préstamo' WHERE NUMEJ=:NEW.NUMEJ AND ID_MAT=:NEW.ID_MAT;--SI SE PRESTA EL MATERIAL CAMBIA SU ESTADO 
    ELSIF DELETING THEN
        UPDATE EJEMPLAR SET estatus = 'Disponible' WHERE NUMEJ=:OLD.NUMEJ AND ID_MAT=:OLD.ID_MAT; --SI SE ELIMINA UN PRESTAMO, EL EJEMPLAR VUELVE A ESTAR DISPONIBLE
    END IF;
END;
/

--PROCEDIMIENTO PARA INGRESAR UN PRESTAMO
--TOMA EN CUENTA SI HAY MULTAS ANTES Y SI SÍ, NO SE HACE EL PRESTAMO
CREATE OR REPLACE PROCEDURE spInsertaPrestamo
(vF_inic DATE,/* vF_fin DATE*/ vMulta NUMBER/*,vRefre NUMBER*/,vF_devol DATE,vID_lec NUMBER,vNumEj NUMBER,vID_Mat NUMBER )
AS
vTipoLector LECTOR.id_tipo%TYPE;
vDiasPres TIPO_LECTOR.lim_dia%TYPE;
vRefre NUMBER;
vF_fin DATE;
vMultaAnterior NUMBER;
vEstatus VARCHAR2(20);
BEGIN

    vMultaAnterior := ftCalculaMulta(vID_lec,vNumEj,vID_mat);
    IF vMultaAnterior>0 THEN--SI EL USUARIO TIENE UNA MULTA NO  SE LE PRESTA EL MATERIAL
        DBMS_OUTPUT.PUT_LINE('ERROR: El id del usuario cuenta con una multa de: '||vmultaanterior);
        RETURN;
    END IF;
    
    SELECT ESTATUS INTO vEstatus FROM EJEMPLAR
    WHERE NUMEJ=vNumEj AND ID_MAT=vID_mat;
    
    --SI EL MATERIAL ESTÁ EN UN ESTADO DIFERENTE A DISPONIBLE, NO SE PRESTA
    
    IF vEstatus<>'Disponible' THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: El material no se puede prestar porque se encuentra '||vEstatus);
        RETURN;
    END IF;
    
    SELECT L.id_tipo,TL.lim_dia,TL.lim_refrendo INTO vTipoLector,vDiasPres,vRefre FROM LECTOR L JOIN TIPO_LECTOR TL ON L.id_tipo=TL.id_tipo
    WHERE L.ID_LECTOR=vID_lec;
    
    vF_fin:=vF_inic+(vDiasPres);
    
    INSERT INTO PRESTAMO VALUES(vF_inic,vF_fin,vMulta,vRefre,vF_devol,vID_lec,vNumEj,vID_Mat);
END;
/

--FUNCION PARA CALCULAR LA MULTA DE UN PRESTAMO
CREATE OR REPLACE FUNCTION ftCalculaMulta
(vID_lec IN prestamo.id_lector%TYPE, vNumEj IN prestamo.numEj%TYPE, vID_Mat IN prestamo.id_mat%TYPE)--TENEMOS QUE TOMAR TODA LA PK COMPLETA DE PRESTAMO
RETURN NUMBER --VA A SER EL TOTAL A DEBER
IS
vMulta NUMBER(6);
vFechaInic DATE;
vFechaFin DATE;
vDias NUMBER(3);
vFechaDevo DATE;
vFechaActual DATE;
BEGIN
    vFechaActual:=SYSDATE;
    BEGIN
    --Tomamos las fechas iniciales y finales del prestamo en cuestion
        SELECT f_inicio,f_venci,f_devol INTO vFechaInic, vFechaFin,vFechaDevo FROM PRESTAMO 
        WHERE (id_lector=vID_lec) AND (multa>0);
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            vFechaInic:=NULL;
    END;
        IF (vfechainic IS NULL) THEN--primero corroboramos que exista algún préstamo de ese lector
            vMulta:=0;
        ELSIF (vfechainic IS NOT NULL) THEN--SI YA HAY ALGUN PRESTAMO
            IF (vFechaDevo)<(vFechaFIn) THEN--SI YA SE ENTREGO A TIEMPO
                vMulta:=0;
            ELSIF (vFechaDevo)>(vFechaFIn) THEN--SI SE ENTREGO A DESTIEMPO
                vDias:=vfechadevo-vfechafin;
                vMulta:=10*vDias;
            ELSIF (vfechaDevo IS NULL) AND (vFechaActual<vFechaFin) THEN --SI AUN NO LO ENTREGO Y EESTOY A TIEMPO
                vMulta:=0;
            ELSIF (vfechaDevo IS NULL) AND (vFechaActual>vFechaFin) THEN --SI AUN NO LO ENTREGO Y NO EESTOY A TIEMPO1
                vDias:=vFechaActual-vFechaFin;
                vMulta:=10*vDias;
            END IF;
        END IF;
        
RETURN (vMulta);
END ftCalculaMulta;
/


INSERT INTO AUTOR VALUES(1234,'Julio','Florencio','Cortazar','Argentina');
INSERT INTO AUTOR VALUES(5678,'Gabriel','Mendez','Mendoza','Colombia');
INSERT INTO AUTOR VALUES(9101,'Pablo','Neruda','Bosoalto','Chile');
INSERT INTO AUTOR VALUES(1121,'Miguel','Martinez','Martinolli','Mexico');

INSERT INTO MATERIAL VALUES(3040000012,'Literatura','Las uvas y el viento','AK304','L');
INSERT INTO MATERIAL VALUES(3040000013,'Literatura','Rayuela','AK306','L');
INSERT INTO MATERIAL VALUES(3050000015,'Programacion','Diseño de bases de datos','IJ204','T');
INSERT INTO MATERIAL VALUES(3050000017,'Programacion','Algoritmos for dummies','IJ208','T');

INSERT INTO CUENTA VALUES(3040000012,1234);
INSERT INTO CUENTA VALUES(3040000013,9101);
INSERT INTO CUENTA VALUES(3050000015,5678);
INSERT INTO CUENTA VALUES(3050000017,1121);

INSERT INTO LIBRO VALUES(3040000012,9874,'5241638947','Segunda','Ciencia');
INSERT INTO LIBRO VALUES(3040000013,6541,'1236595761','Primera','Historia');


INSERT INTO DIRECTOR VALUES(7531,'Erick','Hurtado','Mendez','Doctorado');
INSERT INTO DIRECTOR VALUES(3698,'Miguel','Rodriguez','Morales','Maestria');
INSERT INTO DIRECTOR VALUES(1325,'Maria','Muñoz','Franco','Doctorado');


INSERT INTO TESIS VALUES(3050000015,1,'Sistemas',2004,7531);
INSERT INTO TESIS VALUES(3050000017,2,'Sistemas',2012,1325);


INSERT INTO EJEMPLAR VALUES(1,3050000015,'Disponible');
INSERT INTO EJEMPLAR VALUES(2,3050000015,'Disponible');
INSERT INTO EJEMPLAR VALUES(3,3050000015,'Disponible');
INSERT INTO EJEMPLAR VALUES(4,3050000017,'Disponible');
INSERT INTO EJEMPLAR VALUES(5,3050000017,'Disponible');
INSERT INTO EJEMPLAR VALUES(6,3050000017,'Disponible');
INSERT INTO EJEMPLAR VALUES(7,3040000012,'Disponible');
INSERT INTO EJEMPLAR VALUES(8,3040000012,'Disponible');
INSERT INTO EJEMPLAR VALUES(9,3040000013,'Disponible');
INSERT INTO EJEMPLAR VALUES(10,3040000013,'Disponible');


INSERT INTO TIPO_LECTOR VALUES(1,'E',3,8,1);
INSERT INTO TIPO_LECTOR VALUES(2,'P',5,15,2);
INSERT INTO TIPO_LECTOR VALUES(3,'I',10,30,3);


EXEC spaltalector(1234567890,'Lourdes','Martinez','Muñoz',SYSDATE,5596321511,'Puerto angel','Piloto','9',3);
EXEC spaltalector(1052637489,'Hector','Herrera','Hurtado',SYSDATE,5522336611,'Insurgentes','Del valle','12',1);
EXEC spaltalector(4565321278,'Ingrid','Garcia','Dominguez',SYSDATE,5296748536,'Juan Cosio','Alfaro','9',1);
EXEC spaltalector(7485522063,'Raul','Zarco','Zaragoza',SYSDATE,5643405056,'Rosa the','Alfaro','17',2);


SET SERVEROUTPUT ON;--COMANDO PARAACTIVAR LAS SALIDAS DE PANTALLA
SELECT * FROM PRESTAMO;
SELECT * FROM EJEMPLAR;
SELECT * FROM TIPO_LECTOR;
SELECT * FROM LECTOR;

DELETE FROM PRESTAMO WHERE NUMEJ=1;

--SPINSERTAPRESTAMO(vF_inic DATE,vMulta NUMBER,vF_devol DATE,vID_lec NUMBER,vNumEj NUMBER,vID_Mat NUMBER )
EXEC spinsertaprestamo(SYSDATE,0,NULL,7485522063,1,3050000015);
EXEC spinsertaprestamo(SYSDATE,0,NULL,7485522063,4,3050000017);

EXEC spinsertaprestamo(SYSDATE,0,NULL,7485522063,6,3050000017);
EXEC spinsertaprestamo(SYSDATE,0,NULL,1052637489,1,3050000015);


CREATE TABLE PRESTAMO_RESUELTO (
	f_inicio       DATE        NOT NULL,--HACERLOS UNICOS O UNIRLOS EN UNA PK
	f_venci        DATE        NOT NULL,
	multa          NUMBER(4)   ,--DEBERIA DE SER OPCIONAL LA MULTA
	f_devol        DATE,
    id_lector      NUMBER(10),--HACERLO UNICO
	numEj          NUMBER(10),--HACERLO UNICO
	id_mat         NUMBER(10),--HACERLO UNICO
    CONSTRAINT fk_preRE_nejYidm FOREIGN KEY (numEj,id_mat) REFERENCES  EJEMPLAR (numEj,id_mat) ON DELETE CASCADE,
    CONSTRAINT fk_preRE_idLec FOREIGN KEY (id_lector) REFERENCES  LECTOR (id_lector),
    CONSTRAINT pk_preRE_idPre PRIMARY KEY (f_inicio,id_lector,numEj,id_mat)--AHORA SÍ LA PK DE PRESTAMO SÍ TIENE SENIDO Y ASÍ NOS CORROBORAMOS DE QUE LAS PK NO SE REPITAN
);

SELECT * FROM prestamo;
SELECT * FROM prestamo_resuelto;
SELECT * FROM EJEMPLAR;

EXEC spDevolverEjemplar(7485522063,1,3050000015);

CREATE OR REPLACE PROCEDURE spDevolverEjemplar--METODO PARA REGRESAR UN EJEMPLAR
(vID_lec  NUMBER, vNumEj  NUMBER, vID_Mat  NUMBER )
AS
BEGIN     
    DELETE FROM PRESTAMO WHERE ID_LECTOR=vID_lec AND NUMEJ=vNumEj AND ID_MAT=vID_Mat;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: El ejemplar que se intenta devolver no se encuentra en préstamo ');
        RETURN;
END;
/

COMMIT;
SELECT * FROM prestamo_resuelto;

CREATE OR REPLACE TRIGGER tgInsertarPrestamoResuelto 
BEFORE DELETE ON PRESTAMO
FOR EACH ROW
BEGIN 
INSERT INTO PRESTAMO_RESUELTO VALUES(:OLD.F_INICIO,:OLD.F_VENCI,:OLD.MULTA,SYSDATE,:OLD.ID_LECTOR,:OLD.NUMEJ,:OLD.ID_MAT);
END;
/

-- DROP TABLE AUTOR        CASCADE CONSTRAINTS;
-- DROP TABLE CUENTA       CASCADE CONSTRAINTS;
-- DROP TABLE MATERIAL     CASCADE CONSTRAINTS;
-- DROP TABLE LIBRO        CASCADE CONSTRAINTS;
-- DROP TABLE TESIS        CASCADE CONSTRAINTS;
-- DROP TABLE DIRECTOR     CASCADE CONSTRAINTS;
-- DROP TABLE EJEMPLAR     CASCADE CONSTRAINTS;
-- DROP TABLE PRESTAMO     CASCADE CONSTRAINTS;
-- DROP TABLE LECTOR       CASCADE CONSTRAINTS;
-- DROP TABLE TIPO_LECTOR  CASCADE CONSTRAINTS;
