import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "../stores/auth";
import AdminCoursesView from "../views/admin/AdminCoursesView.vue";
import AdminEventsView from "../views/admin/AdminEventsView.vue";
import DashboardView from "../views/DashboardView.vue";
import CalendarView from "../views/CalendarView.vue";
import AssignmentsView from "../views/AssignmentsView.vue";
import MaterialsView from "../views/MaterialsView.vue";
import CoursesView from "../views/CoursesView.vue";
import AdminLoginView from "../views/admin/AdminLoginView.vue";
import AdminDashboardView from "../views/admin/AdminDashboardView.vue";
import AdminMaterialsView from '../views/admin/AdminMaterialsView.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      name: "dashboard",
      component: DashboardView,
    },
    {
      path: "/calendar",
      name: "calendar",
      component: CalendarView,
    },
    {
      path: "/assignments",
      name: "assignments",
      component: AssignmentsView,
    },
    {
      path: "/materials",
      name: "materials",
      component: MaterialsView,
    },
    {
      path: "/courses",
      name: "courses",
      component: CoursesView,
    },
    {
      path: "/admin/login",
      name: "admin-login",
      component: AdminLoginView,
    },
    {
      path: "/admin/courses",
      name: "admin-courses",
      component: AdminCoursesView,
      meta: {
        requiresAuth: true,
        requiresAdmin: true,
      },
    },
    {
      path: '/admin/materials',
      name: 'admin-materials',
      component: AdminMaterialsView,
      meta: {
        requiresAuth: true,
        requiresAdmin: true,
      },
    },
    {
      path: "/admin/events",
      name: "admin-events",
      component: AdminEventsView,
      meta: {
        requiresAuth: true,
        requiresAdmin: true,
      },
    },
    {
      path: "/admin",
      name: "admin",
      component: AdminDashboardView,
      meta: {
        requiresAuth: true,
        requiresAdmin: true,
      },
    },
  ],
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();

  await auth.initialize();

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return {
      name: "admin-login",
      query: {
        redirect: to.fullPath,
      },
    };
  }

  if (to.meta.requiresAdmin && !auth.isAdmin) {
    return { name: "dashboard" };
  }

  if (to.name === "admin-login" && auth.isAdmin) {
    return { name: "admin" };
  }

  return true;
});
