ALTER TABLE public.events
ADD CONSTRAINT events_discipline_course_fk
FOREIGN KEY (discipline_id, course_id)
REFERENCES public.disciplines (id, course_id)
ON UPDATE CASCADE;
