
CREATE OR REPLACE FUNCTION public.record_event_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_old_values jsonb;
    v_new_values jsonb;
    v_event_id uuid;
    v_action text;
    v_entity_type text;
BEGIN
    v_entity_type := CASE
        WHEN TG_TABLE_NAME = 'events'
            THEN 'event'
        ELSE 'occurrence_override'
    END;

    IF TG_OP = 'INSERT' THEN
        v_new_values := to_jsonb(NEW);

        v_event_id := CASE
            WHEN v_entity_type = 'event'
                THEN NEW.id
            ELSE NEW.event_id
        END;

        v_action := 'insert';

    ELSIF TG_OP = 'UPDATE' THEN
        v_old_values := to_jsonb(OLD);
        v_new_values := to_jsonb(NEW);

        v_event_id := CASE
            WHEN v_entity_type = 'event'
                THEN NEW.id
            ELSE NEW.event_id
        END;

        v_action := 'update';

    ELSIF TG_OP = 'DELETE' THEN
        v_old_values := to_jsonb(OLD);

        v_event_id := CASE
            WHEN v_entity_type = 'event'
                THEN NULL
            ELSE OLD.event_id
        END;

        v_action := 'delete';
    END IF;

    INSERT INTO public.event_history (
        event_id,
        entity_type,
        action,
        actor_id,
        old_values,
        new_values
    )
    VALUES (
        v_event_id,
        v_entity_type,
        v_action,
        auth.uid(),
        v_old_values,
        v_new_values
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;
