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


select 
r.bezeichnung as Rohstoff, 
nvl(sum(l.menge),0) as "Soll-Wert",
r.menge as "Ist-Wert", 
r.menge-nvl(sum(l.menge),0) as Differenz, 
r.eh_id as Einheit
from icf_rohstoffe r join icf_lagerbewegungen l
on r.id = l.rstf_id
group by l.rstf_id;



select
r.bezeichnung as Rohstoff,
nvl(x.menge,0) as Sollwert,
r.menge as IstWert,
r.eh_id as Einheit
from icf_rohstoffe r left outer join
(select rstf_id as id, sum(menge) as menge
from icf_lagerbewegungen
group by rstf_id) x
on r.id = x.id

insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,1,100);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,2,10);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,3,50);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,4,80);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,5,60);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,6,200);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,7,50);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,8,70);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,1,100);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,2,10);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,3,50);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,4,80);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,5,60);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,6,200);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,7,50);
insert into icf_lagerbewegungen values (LBWG_ID_SEQ.nextval,sysdate,8,70);
