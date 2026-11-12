import { computed, ref } from "vue";
import { defineStore } from "pinia";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import type { Database } from "../types/database";

type Profile = Database["public"]["Tables"]["profiles"]["Row"];

export const useAuthStore = defineStore("auth", () => {
  const session = ref<Session | null>(null);
  const profile = ref<Profile | null>(null);

  const loading = ref(false);
  const initialized = ref(false);

  let authSubscription: { unsubscribe: () => void } | null = null;

  const user = computed(() => session.value?.user ?? null);
  const isAuthenticated = computed(() => user.value !== null);
  const isAdmin = computed(() => profile.value?.role === "admin");

  async function refreshProfile() {
    const userId = session.value?.user.id;

    if (!userId) {
      profile.value = null;
      return;
    }

    const { data, error } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", userId)
      .maybeSingle();

    if (error) {
      profile.value = null;
      throw error;
    }

    profile.value = data;
  }

  async function initialize() {
    if (initialized.value) return;

    loading.value = true;

    try {
      const { data, error } = await supabase.auth.getSession();

      if (error) throw error;

      session.value = data.session;

      if (session.value) {
        await refreshProfile();
      }

      authSubscription ??= supabase.auth.onAuthStateChange(
        (_event, nextSession) => {
          session.value = nextSession;

          if (!nextSession) {
            profile.value = null;
            return;
          }

          // Avoid making another Supabase request inside the auth callback.
          queueMicrotask(() => {
            void refreshProfile().catch((error: unknown) => {
              console.error("Failed to refresh user profile:", error);
            });
          });
        },
      ).data.subscription;

      initialized.value = true;
    } finally {
      loading.value = false;
    }
  }

  async function signIn(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) throw error;

    session.value = data.session;
    await refreshProfile();

    return data;
  }

  async function signOut() {
    const { error } = await supabase.auth.signOut();

    if (error) throw error;

    session.value = null;
    profile.value = null;
  }

  return {
    session,
    user,
    profile,
    loading,
    initialized,
    isAuthenticated,
    isAdmin,
    initialize,
    refreshProfile,
    signIn,
    signOut,
  };
});
