import { useAuthStore } from "~/stores/auth";

export interface ApiError {
  detail: string;
}

export function useApi() {
  const config = useRuntimeConfig();
  const auth = useAuthStore();

  async function request<T>(path: string, opts: any = {}): Promise<T> {
    const url = `${config.public.apiBase}${path}`;

    console.group(`🚀 API ${opts.method || "GET"} ${url}`);

    console.log("URL:", url);
    console.log("Method:", opts.method);
    console.log("Headers:", {
      ...(opts.headers || {}),
      ...(auth.token
        ? {
            Authorization: `Bearer ${auth.token}`,
          }
        : {}),
    });

    console.log("Params:", opts.params ?? null);
    console.log("Body:", opts.body ?? null);

    try {
      const response = await $fetch<T>(path, {
        baseURL: config.public.apiBase,
        ...opts,
        headers: {
          ...(opts.headers || {}),
          ...(auth.token
            ? {
                Authorization: `Bearer ${auth.token}`,
              }
            : {}),
        },
      });

      console.log("✅ Response:", response);
      console.groupEnd();

      return response;
    } catch (err: any) {
      console.error("❌ API ERROR");
      console.error("Status:", err?.response?.status);
      console.error("Status Text:", err?.response?.statusText);
      console.error("Message:", err?.message);
      console.error("Response Data:", err?.data);
      console.error("Full Error:", err);

      // Laravel Validation Error
      if (err?.data?.errors) {
        console.log("========== VALIDATION ERRORS ==========");

        Object.entries(err.data.errors).forEach(([field, messages]) => {
          console.log(`${field}:`, messages);
        });

        console.log("=======================================");
      }

      // FastAPI Validation Error
      if (Array.isArray(err?.data?.detail)) {
        console.log("========== FASTAPI VALIDATION ==========");

        err.data.detail.forEach((e: any) => {
          console.log({
            field: e.loc,
            message: e.msg,
            type: e.type,
          });
        });

        console.log("========================================");
      }

      if (err?.response?.status === 401) {
        console.warn("Token expired, logout...");
        auth.logout();
      }

      console.groupEnd();

      const detail =
        err?.data?.detail ||
        err?.data?.message ||
        err?.message ||
        "Terjadi kesalahan tak terduga.";

      throw new Error(
        typeof detail === "string" ? detail : JSON.stringify(detail, null, 2),
      );
    }
  }

  return {
    get: <T>(path: string, params?: Record<string, any>) =>
      request<T>(path, {
        method: "GET",
        params,
      }),

    post: <T>(path: string, body?: any) =>
      request<T>(path, {
        method: "POST",
        body,
      }),

    patch: <T>(path: string, body?: any) =>
      request<T>(path, {
        method: "PATCH",
        body,
      }),

    del: <T>(path: string) =>
      request<T>(path, {
        method: "DELETE",
      }),
  };
}
