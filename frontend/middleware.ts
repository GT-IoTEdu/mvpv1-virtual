import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const ADMIN_PROTECTED_PREFIX = "/dashboard/admin";
const SESSION_COOKIE_CANDIDATES = ["session", "__Secure-session"];

function hasAuthCookie(request: NextRequest): boolean {
  return SESSION_COOKIE_CANDIDATES.some((name) => {
    const cookieValue = request.cookies.get(name)?.value;
    return Boolean(cookieValue && cookieValue.trim().length > 0);
  });
}

export function middleware(request: NextRequest) {
  const { pathname, search } = request.nextUrl;

  if (!pathname.startsWith(ADMIN_PROTECTED_PREFIX)) {
    return NextResponse.next();
  }

  if (hasAuthCookie(request)) {
    return NextResponse.next();
  }

  const loginUrl = new URL("/login", request.url);
  const redirectTo = `${pathname}${search}`;
  loginUrl.searchParams.set("next", redirectTo);

  return NextResponse.redirect(loginUrl);
}

export const config = {
  matcher: ["/dashboard/admin/:path*"],
};
