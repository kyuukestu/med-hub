
-- =========================================================
-- Migration 005: Notifications Infrastructure
-- =========================================================

-- ---------------------------------------------------------
-- 1. Notification enums
-- ---------------------------------------------------------

create type public.notification_category as enum (
    'announcement',
    'assignment_published',
    'assignment_updated',
    'deadline_reminder',
    'event_created',
    'event_updated',
    'event_cancelled',
    'material_published',
    'material_updated',
    'system'
);

create type public.notification_entity_type as enum (
    'event',
    'assignment',
    'material',
    'course'
);


-- ---------------------------------------------------------
-- 2. Notifications
-- ---------------------------------------------------------

create table public.notifications (
    id uuid primary key default gen_random_uuid(),

    recipient_id uuid not null
        references public.profiles(id)
        on delete cascade,

    actor_id uuid
        references public.profiles(id)
        on delete set null,

    category public.notification_category not null,

    title text not null,
    body text not null,

    related_entity_type public.notification_entity_type,
    related_entity_id uuid,

    -- Optional application-level data, such as contextual
    -- details or identifiers needed by the frontend.
    metadata jsonb not null default '{}'::jsonb,

    -- Optional key used to prevent duplicate notifications.
    -- Example: assignment-deadline:<assignment-id>:<user-id>
    deduplication_key text,

    created_at timestamptz not null default now(),
    read_at timestamptz,
    expires_at timestamptz,

    constraint notifications_title_not_empty
        check (length(trim(title)) > 0),

    constraint notifications_body_not_empty
        check (length(trim(body)) > 0),

    constraint notifications_metadata_object
        check (jsonb_typeof(metadata) = 'object'),

    constraint notifications_entity_reference_complete
        check (
            (related_entity_type is null and related_entity_id is null)
            or
            (related_entity_type is not null and related_entity_id is not null)
        ),

    constraint notifications_deduplication_key_not_empty
        check (
            deduplication_key is null
            or length(trim(deduplication_key)) > 0
        ),

    constraint notifications_expiration_valid
        check (
            expires_at is null
            or expires_at > created_at
        )
);


-- ---------------------------------------------------------
-- 3. Push subscriptions
-- ---------------------------------------------------------

create table public.push_subscriptions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    endpoint text not null,
    p256dh_key text not null,
    auth_key text not null,

    expiration_time timestamptz,

    device_label text,
    user_agent text,

    last_used_at timestamptz,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint push_subscriptions_endpoint_not_empty
        check (length(trim(endpoint)) > 0),

    constraint push_subscriptions_endpoint_https
        check (endpoint ~ '^https://'),

    constraint push_subscriptions_p256dh_not_empty
        check (length(trim(p256dh_key)) > 0),

    constraint push_subscriptions_auth_not_empty
        check (length(trim(auth_key)) > 0),

    constraint push_subscriptions_unique_endpoint
        unique (endpoint)
);


-- ---------------------------------------------------------
-- 4. Indexes
-- ---------------------------------------------------------

-- Retrieve a user's notifications, newest first.
create index notifications_recipient_created_idx
on public.notifications(recipient_id, created_at desc);

-- Efficiently retrieve unread notifications.
create index notifications_recipient_unread_idx
on public.notifications(recipient_id, created_at desc)
where read_at is null;

-- Support filtering notifications by category.
create index notifications_recipient_category_idx
on public.notifications(recipient_id, category, created_at desc);

-- Support scheduled cleanup of expired notifications.
create index notifications_expires_at_idx
on public.notifications(expires_at)
where expires_at is not null;

-- Prevent duplicate notifications for the same recipient.
create unique index notifications_deduplication_idx
on public.notifications(recipient_id, deduplication_key)
where deduplication_key is not null;

-- Retrieve all push subscriptions associated with a user.
create index push_subscriptions_user_id_idx
on public.push_subscriptions(user_id);


-- ---------------------------------------------------------
-- 5. Timestamp triggers
-- ---------------------------------------------------------

-- Reuse set_updated_at() from Migration 001.

create trigger set_push_subscriptions_updated_at
before update on public.push_subscriptions
for each row
execute function public.set_updated_at();


-- ---------------------------------------------------------
-- 6. Row Level Security
-- ---------------------------------------------------------

alter table public.notifications
enable row level security;

alter table public.push_subscriptions
enable row level security;


-- ---------------------------------------------------------
-- 6.1 Notification policies
-- ---------------------------------------------------------

-- Users can view their own notifications.
-- Expired notifications are hidden from the notification centre.

create policy "Users can view their own notifications"
on public.notifications
for select
to authenticated
using (
    recipient_id = (select auth.uid())
    and (
        expires_at is null
        or expires_at > now()
    )
);


-- Users can update the read status of their own notifications.
-- Column-level permissions below prevent modification of
-- notification content and other protected fields.

create policy "Users can mark their own notifications as read"
on public.notifications
for update
to authenticated
using (
    recipient_id = (select auth.uid())
    and (
        expires_at is null
        or expires_at > now()
    )
)
with check (
    recipient_id = (select auth.uid())
);


-- Users can delete their own notifications.

create policy "Users can delete their own notifications"
on public.notifications
for delete
to authenticated
using (
    recipient_id = (select auth.uid())
);


-- ---------------------------------------------------------
-- 6.2 Push subscription policies
-- ---------------------------------------------------------

-- Users can manage push subscriptions associated with
-- their own accounts and devices.

create policy "Users can manage their own push subscriptions"
on public.push_subscriptions
for all
to authenticated
using (
    user_id = (select auth.uid())
)
with check (
    user_id = (select auth.uid())
);


-- ---------------------------------------------------------
-- 7. Permissions
-- ---------------------------------------------------------

-- Notifications:
-- Users can read and delete their own notifications.
-- They can update only the read_at column.
-- Notification creation is reserved for trusted backend
-- operations using the service role.

grant select, delete
on public.notifications
to authenticated;

grant update (read_at)
on public.notifications
to authenticated;


-- Push subscriptions:
-- Users can register, view, update and remove their own
-- device subscriptions.

grant select, insert, update, delete
on public.push_subscriptions
to authenticated;
