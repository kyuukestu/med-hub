export type Json = string | number | boolean | null | {
  [key: string]: Json | undefined;
} | Json[];

export type Database = {
  "graphql_public": {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      "graphql": {
        Args: {
          "extensions"?: Json;
          "operationName"?: string;
          "query"?: string;
          "variables"?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  "public": {
    Tables: {
      "assignments": {
        Row: {
          "assigned_at": string;
          "course_id": string;
          "created_at": string;
          "created_by": string | null;
          "description": string | null;
          "discipline_id": string | null;
          "due_at": string | null;
          "id": string;
          "instructions": string | null;
          "status": Database["public"]["Enums"]["assignment_status"];
          "submission_location": string | null;
          "submission_method": string | null;
          "submission_url": string | null;
          "title": string;
          "updated_at": string;
          "updated_by": string | null;
        };
        ComputedFields: never;
        Insert: {
          "assigned_at"?: string;
          "course_id": string;
          "created_at"?: string;
          "created_by"?: string | null;
          "description"?: string | null;
          "discipline_id"?: string | null;
          "due_at"?: string | null;
          "id"?: string;
          "instructions"?: string | null;
          "status"?: Database["public"]["Enums"]["assignment_status"];
          "submission_location"?: string | null;
          "submission_method"?: string | null;
          "submission_url"?: string | null;
          "title": string;
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Update: {
          "assigned_at"?: string;
          "course_id"?: string;
          "created_at"?: string;
          "created_by"?: string | null;
          "description"?: string | null;
          "discipline_id"?: string | null;
          "due_at"?: string | null;
          "id"?: string;
          "instructions"?: string | null;
          "status"?: Database["public"]["Enums"]["assignment_status"];
          "submission_location"?: string | null;
          "submission_method"?: string | null;
          "submission_url"?: string | null;
          "title"?: string;
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "assignments_course_id_fkey";
            columns: ["course_id"];
            isOneToOne: false;
            referencedRelation: "courses";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "assignments_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "assignments_discipline_id_fkey";
            columns: ["discipline_id"];
            isOneToOne: false;
            referencedRelation: "disciplines";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "assignments_updated_by_fkey";
            columns: ["updated_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      "courses": {
        Row: {
          "code": string;
          "created_at": string;
          "description": string | null;
          "id": string;
          "is_active": boolean;
          "name": string;
          "sort_order": number;
          "updated_at": string;
        };
        ComputedFields: never;
        Insert: {
          "code": string;
          "created_at"?: string;
          "description"?: string | null;
          "id"?: string;
          "is_active"?: boolean;
          "name": string;
          "sort_order"?: number;
          "updated_at"?: string;
        };
        Update: {
          "code"?: string;
          "created_at"?: string;
          "description"?: string | null;
          "id"?: string;
          "is_active"?: boolean;
          "name"?: string;
          "sort_order"?: number;
          "updated_at"?: string;
        };
        Relationships: [];
      };
      "disciplines": {
        Row: {
          "code": string;
          "course_id": string;
          "created_at": string;
          "description": string | null;
          "id": string;
          "is_active": boolean;
          "name": string;
          "sort_order": number;
          "updated_at": string;
        };
        ComputedFields: never;
        Insert: {
          "code": string;
          "course_id": string;
          "created_at"?: string;
          "description"?: string | null;
          "id"?: string;
          "is_active"?: boolean;
          "name": string;
          "sort_order"?: number;
          "updated_at"?: string;
        };
        Update: {
          "code"?: string;
          "course_id"?: string;
          "created_at"?: string;
          "description"?: string | null;
          "id"?: string;
          "is_active"?: boolean;
          "name"?: string;
          "sort_order"?: number;
          "updated_at"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "disciplines_course_id_fkey";
            columns: ["course_id"];
            isOneToOne: false;
            referencedRelation: "courses";
            referencedColumns: ["id"];
          },
        ];
      };
      "event_history": {
        Row: {
          "action": string;
          "actor_id": string | null;
          "created_at": string;
          "entity_type": string;
          "event_id": string | null;
          "id": string;
          "new_values": Json | null;
          "old_values": Json | null;
        };
        ComputedFields: never;
        Insert: {
          "action": string;
          "actor_id"?: string | null;
          "created_at"?: string;
          "entity_type": string;
          "event_id"?: string | null;
          "id"?: string;
          "new_values"?: Json | null;
          "old_values"?: Json | null;
        };
        Update: {
          "action"?: string;
          "actor_id"?: string | null;
          "created_at"?: string;
          "entity_type"?: string;
          "event_id"?: string | null;
          "id"?: string;
          "new_values"?: Json | null;
          "old_values"?: Json | null;
        };
        Relationships: [
          {
            foreignKeyName: "event_history_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "event_history_event_id_fkey";
            columns: ["event_id"];
            isOneToOne: false;
            referencedRelation: "events";
            referencedColumns: ["id"];
          },
        ];
      };
      "event_occurrence_overrides": {
        Row: {
          "created_at": string;
          "created_by": string | null;
          "ends_at": string | null;
          "event_id": string;
          "id": string;
          "original_start": string;
          "reason": string | null;
          "starts_at": string | null;
          "status": Database["public"]["Enums"]["occurrence_override_status"];
          "updated_at": string;
          "updated_by": string | null;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "created_by"?: string | null;
          "ends_at"?: string | null;
          "event_id": string;
          "id"?: string;
          "original_start": string;
          "reason"?: string | null;
          "starts_at"?: string | null;
          "status": Database["public"]["Enums"]["occurrence_override_status"];
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Update: {
          "created_at"?: string;
          "created_by"?: string | null;
          "ends_at"?: string | null;
          "event_id"?: string;
          "id"?: string;
          "original_start"?: string;
          "reason"?: string | null;
          "starts_at"?: string | null;
          "status"?: Database["public"]["Enums"]["occurrence_override_status"];
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "event_occurrence_overrides_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "event_occurrence_overrides_event_id_fkey";
            columns: ["event_id"];
            isOneToOne: false;
            referencedRelation: "events";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "event_occurrence_overrides_updated_by_fkey";
            columns: ["updated_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      "events": {
        Row: {
          "all_day": boolean;
          "course_id": string | null;
          "created_at": string;
          "created_by": string | null;
          "description": string | null;
          "discipline_id": string | null;
          "ends_at": string;
          "event_type": Database["public"]["Enums"]["event_type"];
          "id": string;
          "location": string | null;
          "recurrence_rule": string | null;
          "recurrence_timezone": string;
          "starts_at": string;
          "status": Database["public"]["Enums"]["event_status"];
          "title": string;
          "updated_at": string;
          "updated_by": string | null;
        };
        ComputedFields: never;
        Insert: {
          "all_day"?: boolean;
          "course_id"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "description"?: string | null;
          "discipline_id"?: string | null;
          "ends_at": string;
          "event_type": Database["public"]["Enums"]["event_type"];
          "id"?: string;
          "location"?: string | null;
          "recurrence_rule"?: string | null;
          "recurrence_timezone"?: string;
          "starts_at": string;
          "status"?: Database["public"]["Enums"]["event_status"];
          "title": string;
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Update: {
          "all_day"?: boolean;
          "course_id"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "description"?: string | null;
          "discipline_id"?: string | null;
          "ends_at"?: string;
          "event_type"?: Database["public"]["Enums"]["event_type"];
          "id"?: string;
          "location"?: string | null;
          "recurrence_rule"?: string | null;
          "recurrence_timezone"?: string;
          "starts_at"?: string;
          "status"?: Database["public"]["Enums"]["event_status"];
          "title"?: string;
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "events_course_id_fkey";
            columns: ["course_id"];
            isOneToOne: false;
            referencedRelation: "courses";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "events_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "events_discipline_id_fkey";
            columns: ["discipline_id"];
            isOneToOne: false;
            referencedRelation: "disciplines";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "events_updated_by_fkey";
            columns: ["updated_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      "material_links": {
        Row: {
          "assignment_id": string | null;
          "course_id": string | null;
          "created_at": string;
          "created_by": string | null;
          "discipline_id": string | null;
          "event_id": string | null;
          "id": string;
          "material_id": string;
          "relationship_type":
            Database["public"]["Enums"]["material_relationship_type"];
        };
        ComputedFields: never;
        Insert: {
          "assignment_id"?: string | null;
          "course_id"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "discipline_id"?: string | null;
          "event_id"?: string | null;
          "id"?: string;
          "material_id": string;
          "relationship_type"?:
            Database["public"]["Enums"]["material_relationship_type"];
        };
        Update: {
          "assignment_id"?: string | null;
          "course_id"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "discipline_id"?: string | null;
          "event_id"?: string | null;
          "id"?: string;
          "material_id"?: string;
          "relationship_type"?:
            Database["public"]["Enums"]["material_relationship_type"];
        };
        Relationships: [
          {
            foreignKeyName: "material_links_assignment_id_fkey";
            columns: ["assignment_id"];
            isOneToOne: false;
            referencedRelation: "assignments";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "material_links_course_id_fkey";
            columns: ["course_id"];
            isOneToOne: false;
            referencedRelation: "courses";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "material_links_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "material_links_discipline_course_fk";
            columns: ["discipline_id", "course_id"];
            isOneToOne: false;
            referencedRelation: "disciplines";
            referencedColumns: ["id", "course_id"];
          },
          {
            foreignKeyName: "material_links_event_id_fkey";
            columns: ["event_id"];
            isOneToOne: false;
            referencedRelation: "events";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "material_links_material_id_fkey";
            columns: ["material_id"];
            isOneToOne: false;
            referencedRelation: "materials";
            referencedColumns: ["id"];
          },
        ];
      };
      "material_versions": {
        Row: {
          "created_at": string;
          "file_size_bytes": number;
          "id": string;
          "material_id": string;
          "mime_type": string | null;
          "original_filename": string;
          "sha256_hash": string | null;
          "storage_bucket": string;
          "storage_path": string;
          "uploaded_by": string | null;
          "verification_status":
            Database["public"]["Enums"]["material_verification_status"];
          "version_notes": string | null;
          "version_number": number;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "file_size_bytes": number;
          "id"?: string;
          "material_id": string;
          "mime_type"?: string | null;
          "original_filename": string;
          "sha256_hash"?: string | null;
          "storage_bucket"?: string;
          "storage_path": string;
          "uploaded_by"?: string | null;
          "verification_status"?:
            Database["public"]["Enums"]["material_verification_status"];
          "version_notes"?: string | null;
          "version_number": number;
        };
        Update: {
          "created_at"?: string;
          "file_size_bytes"?: number;
          "id"?: string;
          "material_id"?: string;
          "mime_type"?: string | null;
          "original_filename"?: string;
          "sha256_hash"?: string | null;
          "storage_bucket"?: string;
          "storage_path"?: string;
          "uploaded_by"?: string | null;
          "verification_status"?:
            Database["public"]["Enums"]["material_verification_status"];
          "version_notes"?: string | null;
          "version_number"?: number;
        };
        Relationships: [
          {
            foreignKeyName: "material_versions_material_id_fkey";
            columns: ["material_id"];
            isOneToOne: false;
            referencedRelation: "materials";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "material_versions_uploaded_by_fkey";
            columns: ["uploaded_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      "materials": {
        Row: {
          "academic_year": string | null;
          "aliases": (string)[];
          "author": string | null;
          "chapter_number": string | null;
          "chapter_title": string | null;
          "created_at": string;
          "created_by": string | null;
          "current_version_id": string | null;
          "description": string | null;
          "edition": string | null;
          "external_url": string | null;
          "format": Database["public"]["Enums"]["material_format"];
          "id": string;
          "is_published": boolean;
          "isbn": string | null;
          "material_type": Database["public"]["Enums"]["material_type"];
          "page_range": string | null;
          "publication_title": string | null;
          "publication_year": number | null;
          "publisher": string | null;
          "source": Database["public"]["Enums"]["material_source"];
          "title": string;
          "updated_at": string;
          "updated_by": string | null;
        };
        ComputedFields: never;
        Insert: {
          "academic_year"?: string | null;
          "aliases"?: (string)[];
          "author"?: string | null;
          "chapter_number"?: string | null;
          "chapter_title"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "current_version_id"?: string | null;
          "description"?: string | null;
          "edition"?: string | null;
          "external_url"?: string | null;
          "format"?: Database["public"]["Enums"]["material_format"];
          "id"?: string;
          "is_published"?: boolean;
          "isbn"?: string | null;
          "material_type"?: Database["public"]["Enums"]["material_type"];
          "page_range"?: string | null;
          "publication_title"?: string | null;
          "publication_year"?: number | null;
          "publisher"?: string | null;
          "source": Database["public"]["Enums"]["material_source"];
          "title": string;
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Update: {
          "academic_year"?: string | null;
          "aliases"?: (string)[];
          "author"?: string | null;
          "chapter_number"?: string | null;
          "chapter_title"?: string | null;
          "created_at"?: string;
          "created_by"?: string | null;
          "current_version_id"?: string | null;
          "description"?: string | null;
          "edition"?: string | null;
          "external_url"?: string | null;
          "format"?: Database["public"]["Enums"]["material_format"];
          "id"?: string;
          "is_published"?: boolean;
          "isbn"?: string | null;
          "material_type"?: Database["public"]["Enums"]["material_type"];
          "page_range"?: string | null;
          "publication_title"?: string | null;
          "publication_year"?: number | null;
          "publisher"?: string | null;
          "source"?: Database["public"]["Enums"]["material_source"];
          "title"?: string;
          "updated_at"?: string;
          "updated_by"?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "materials_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "materials_current_version_fk";
            columns: ["current_version_id", "id"];
            isOneToOne: false;
            referencedRelation: "material_versions";
            referencedColumns: ["id", "material_id"];
          },
          {
            foreignKeyName: "materials_updated_by_fkey";
            columns: ["updated_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      "notifications": {
        Row: {
          "actor_id": string | null;
          "body": string;
          "category": Database["public"]["Enums"]["notification_category"];
          "created_at": string;
          "deduplication_key": string | null;
          "expires_at": string | null;
          "id": string;
          "metadata": NonNullable<Json>;
          "read_at": string | null;
          "recipient_id": string;
          "related_entity_id": string | null;
          "related_entity_type":
            | Database["public"]["Enums"]["notification_entity_type"]
            | null;
          "title": string;
        };
        ComputedFields: never;
        Insert: {
          "actor_id"?: string | null;
          "body": string;
          "category": Database["public"]["Enums"]["notification_category"];
          "created_at"?: string;
          "deduplication_key"?: string | null;
          "expires_at"?: string | null;
          "id"?: string;
          "metadata"?: NonNullable<Json>;
          "read_at"?: string | null;
          "recipient_id": string;
          "related_entity_id"?: string | null;
          "related_entity_type"?:
            | Database["public"]["Enums"]["notification_entity_type"]
            | null;
          "title": string;
        };
        Update: {
          "actor_id"?: string | null;
          "body"?: string;
          "category"?: Database["public"]["Enums"]["notification_category"];
          "created_at"?: string;
          "deduplication_key"?: string | null;
          "expires_at"?: string | null;
          "id"?: string;
          "metadata"?: NonNullable<Json>;
          "read_at"?: string | null;
          "recipient_id"?: string;
          "related_entity_id"?: string | null;
          "related_entity_type"?:
            | Database["public"]["Enums"]["notification_entity_type"]
            | null;
          "title"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notifications_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notifications_recipient_id_fkey";
            columns: ["recipient_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      "profiles": {
        Row: {
          "created_at": string;
          "display_name": string;
          "id": string;
          "is_active": boolean;
          "role": Database["public"]["Enums"]["app_role"];
          "updated_at": string;
        };
        ComputedFields: never;
        Insert: {
          "created_at"?: string;
          "display_name"?: string;
          "id": string;
          "is_active"?: boolean;
          "role"?: Database["public"]["Enums"]["app_role"];
          "updated_at"?: string;
        };
        Update: {
          "created_at"?: string;
          "display_name"?: string;
          "id"?: string;
          "is_active"?: boolean;
          "role"?: Database["public"]["Enums"]["app_role"];
          "updated_at"?: string;
        };
        Relationships: [];
      };
      "push_subscriptions": {
        Row: {
          "auth_key": string;
          "created_at": string;
          "device_label": string | null;
          "endpoint": string;
          "expiration_time": string | null;
          "id": string;
          "last_used_at": string | null;
          "p256dh_key": string;
          "updated_at": string;
          "user_agent": string | null;
          "user_id": string;
        };
        ComputedFields: never;
        Insert: {
          "auth_key": string;
          "created_at"?: string;
          "device_label"?: string | null;
          "endpoint": string;
          "expiration_time"?: string | null;
          "id"?: string;
          "last_used_at"?: string | null;
          "p256dh_key": string;
          "updated_at"?: string;
          "user_agent"?: string | null;
          "user_id": string;
        };
        Update: {
          "auth_key"?: string;
          "created_at"?: string;
          "device_label"?: string | null;
          "endpoint"?: string;
          "expiration_time"?: string | null;
          "id"?: string;
          "last_used_at"?: string | null;
          "p256dh_key"?: string;
          "updated_at"?: string;
          "user_agent"?: string | null;
          "user_id"?: string;
        };
        Relationships: [
          {
            foreignKeyName: "push_subscriptions_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      "current_user_role": {
        Args: Record<PropertyKey, never>;
        Returns: Database["public"]["Enums"]["app_role"];
      };
    };
    Enums: {
      "app_role": "admin" | "editor" | "student";
      "assignment_status": "draft" | "published" | "cancelled";
      "event_status": "scheduled" | "cancelled";
      "event_type":
        | "class"
        | "practical"
        | "tutorial"
        | "lab"
        | "extra_class"
        | "examination"
        | "general";
      "material_format":
        | "uploaded_file"
        | "external_link"
        | "bibliographic_reference";
      "material_relationship_type":
        | "lecture_resource"
        | "required_reading"
        | "recommended_reading"
        | "supplementary"
        | "reference"
        | "course_resource"
        | "assignment_resource";
      "material_source": "lecturer" | "moodle" | "student" | "external";
      "material_type":
        | "lecture_slides"
        | "lecture_notes"
        | "recommended_reading"
        | "textbook_chapter"
        | "practical_material"
        | "supplementary"
        | "past_exam"
        | "other";
      "material_verification_status":
        | "unverified"
        | "verified"
        | "outdated"
        | "archived";
      "notification_category":
        | "announcement"
        | "assignment_published"
        | "assignment_updated"
        | "deadline_reminder"
        | "event_created"
        | "event_updated"
        | "event_cancelled"
        | "material_published"
        | "material_updated"
        | "system";
      "notification_entity_type":
        | "event"
        | "assignment"
        | "material"
        | "course";
      "occurrence_override_status": "cancelled" | "modified";
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema =
  DatabaseWithoutInternals[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof (
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Tables"
      ]
      & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
        "Views"
      ]
    )
    : never = never,
> = DefaultSchemaTableNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals } ? (
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    & DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Views"
    ]
  )[TableName] extends {
    Row: infer R;
  } ? R
  : never
  : DefaultSchemaTableNameOrOptions extends
    keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[
      DefaultSchemaTableNameOrOptions
    ] extends {
      Row: infer R;
    } ? R
    : never
  : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Insert: infer I;
  } ? I
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I;
    } ? I
    : never
  : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
      "Tables"
    ]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]][
    "Tables"
  ][TableName] extends {
    Update: infer U;
  } ? U
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U;
    } ? U
    : never
  : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]][
      "Enums"
    ]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][
    EnumName
  ]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  } ? keyof DatabaseWithoutInternals[
      PublicCompositeTypeNameOrOptions["schema"]
    ]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends
  { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]][
    "CompositeTypes"
  ][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never;

export const Constants = {
  "graphql_public": {
    Enums: {},
  },
  "public": {
    Enums: {
      "app_role": ["admin", "editor", "student"],
      "assignment_status": ["draft", "published", "cancelled"],
      "event_status": ["scheduled", "cancelled"],
      "event_type": [
        "class",
        "practical",
        "tutorial",
        "lab",
        "extra_class",
        "examination",
        "general",
      ],
      "material_format": [
        "uploaded_file",
        "external_link",
        "bibliographic_reference",
      ],
      "material_relationship_type": [
        "lecture_resource",
        "required_reading",
        "recommended_reading",
        "supplementary",
        "reference",
        "course_resource",
        "assignment_resource",
      ],
      "material_source": ["lecturer", "moodle", "student", "external"],
      "material_type": [
        "lecture_slides",
        "lecture_notes",
        "recommended_reading",
        "textbook_chapter",
        "practical_material",
        "supplementary",
        "past_exam",
        "other",
      ],
      "material_verification_status": [
        "unverified",
        "verified",
        "outdated",
        "archived",
      ],
      "notification_category": [
        "announcement",
        "assignment_published",
        "assignment_updated",
        "deadline_reminder",
        "event_created",
        "event_updated",
        "event_cancelled",
        "material_published",
        "material_updated",
        "system",
      ],
      "notification_entity_type": ["event", "assignment", "material", "course"],
      "occurrence_override_status": ["cancelled", "modified"],
    },
  },
} as const;
