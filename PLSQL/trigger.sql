create or replace procedure sp_produktionspositionen(v_datum in date) as
begin
insert into ICF_produktionen values (v_datum, 'N');

insert into ICF_produktionspositionen (ppos, produktionsmenge, rzpt_id, PRDKT_DATUM)
select row_number() over (order by bp.artk_artnr),sum(bp.menge),r.id, v_datum
from ICF_BESTELLPOSITIONEN bp, ICF_BESTELLUNGEN b, ICF_REZEPTE r
WHERE bp.best_bestnr = b.bestnr
and bp.artk_artnr = r.artk_artnr
and b.beststat_id = 1
and r.status = 'G'
and  b.LIEFERDATUM = v_datum+1
group by bp.artk_artnr,r.id;

update icf_bestellpositionen bp
set bp.PRDKTPOS_PPOS = (select pp.ppos 
                        from icf_produktionspositionen pp 
                        where pp.prdkt_datum = v_datum 
                        and pp.rzpt_id = (select r.id
                                          from icf_rezepte r
                                          where r.artk_artnr=bp.artk_artnr))
where bp.best_bestnr = (select bestnr 
                        from icf_bestellungen 
                        where lieferdatum = v_datum+1);
    update icf_bestellungen
    set beststat_id = 4
    where lieferdatum = v_datum+1
end;
/



create or replace procedure sp_produktionsende(v_datum in date) 
as
    v_rohstoff number;
    v_gesamtmenge float;
    CURSOR cur IS
        select rp.rstf_id as rohstoff, sum(rp.menge) as gesamtmenge
        from icf_produktionspositionen pp join icf_rezeptpositionen rp
        on pp.rzpt_id = rp.rzpt_id
        where pp.prdkt_datum = v_datum
        group by rp.rstf_id;
begin
    OPEN cur;
    LOOP
        FETCH cur INTO v_rohstoff, v_gesamtmenge;
        EXIT WHEN cur%notfound;
               
        update icf_rohstoffe
        set menge = menge-v_gesamtmenge
        where id = v_rohstoff;
        
        insert into icf_lagerbewegungen
        values (EKPOS_ID_SEQ.nextval,sysdate,v_rohstoff,v_gesamtmenge);
        
    END LOOP;
    CLOSE cur;
    
    update icf_produktionen
    set erledigt = 'J'
    where datum = v_datum;
    
    update icf_bestellungen
    set beststat_id = 3
    where lieferdatum = v_datum+1
END;
/



CREATE OR REPLACE TRIGGER trg_upd_rohstoffe
before update of menge on icf_rohstoffe
for each row
begin
    if(:new.menge < 0) then
          raise_application_error (-20107, 'Abbuchung nicht möglich! Zu wenig lagernd');
    End If;

end;
/

CREATE OR REPLACE TRIGGER trg_upd_nachbestellung
after update of menge on icf_rohstoffe
for each row
begin
    if(:new.menge <= :old.mindestbestand) then
          insert into icf_einkaufspositionen
          values (EKP_SEQ.NEXTVAL, :new.id,sysdate);
    End If;

end;
/


create or replace trigger trg_ins_bestellungen
before insert or update on icf_bestellungen
for each row

declare
counter int;

begin
    
    if :old.beststat_id != 1 then
        raise_application_error (-20003, 'Nur bei noch offenen Bestellungen möglich!');
    end if;

    if to_char(:new.lieferdatum,'ddmmyyyy') < to_char(sysdate+1,'ddmmyyyy') then
        raise_application_error (-20003, 'Lieferdatum nicht einhaltbar!');
    end if;
    
    if :new.bestelldatum > sysdate then
        raise_application_error (-20003, 'Bestelldatum in der Zukunft ist nicht erlaubt!');
    end if
    
    select count(*)
    into counter
    from icf_produktionspositionen
    where to_char(DATUM, 'ddmmyyyy') = to_char(:new.lieferdatum-1, 'ddmmyyyy');

    if counter > 0 then
        raise_application_error (-20003, 'Lieferdatum nicht einhaltbar!');
    end if;
end;

create or replace trigger trg_ins_bestellungen
before insert or update on icf_bestellpositionen
for each row
declare
status int;
begin
    select beststat_id
    into status
    from icf_bestellungen
    where bestnr = :new.best_bestnr;
    
    if status != 1 then
       raise_application_error (-20003, 'Nur bei noch offenen Bestellungen möglich!');
    end if;
end;

--MUTATING TABLE

create or replace package state_pkg 
as 
    type ridArray is table of rowid index by pls_integer; 

    newRows     ridArray; 
    emptyRows   ridArray; 
end; 
/ 


create or replace trigger rezepte_status_bius
before insert or update on icf_rezepte
begin
	state_pkg.newRows := state_pkg.emptyRows;
end;
/


create or replace trigger rezepte_status_aiu
AFTER insert or update of status on icf_rezepte for each row
begin
		state_pkg.newRows(state_pkg.newRows.count+1 ) := :new.rowid;
end;
/




create or replace trigger rezept_gueltigkeit
after insert or update of status on icf_rezepte
declare
   kollision number(1);
   koll_err exception;
begin
   for i in 1 .. state_pkg.newRows.count loop      
	   select nvl(max(1),0) into kollision
	   from rezepte rp, rezepte r
	   where  rp.prkt_produktID = r.prkt_produktID 
	   and rp.rowID = state_pkg.newRows(i)   
	   and rp.rowID != r.rowID			
	   and(	rp.status = 'G' and r.status = 'G');								
       
       if kollision = 1 then		
        	   raise koll_err;
       end if;
	end loop;
exception
	when koll_err then raise_application_error(-20100,'Fehler - Darf nicht upgedated werden!');
end;
/	




--constraint bestellung lieferdatum zukunft