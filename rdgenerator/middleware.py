"""svchost patch: Basic Auth middleware
保护网页路由 (form / waiting / generated),  放行 GitHub runner 走的后端接口
"""
import base64
from django.conf import settings
from django.http import HttpResponse

# 这些路径让 GitHub runner 不带 Auth 直接调
# 安全靠 uuid 不可猜 (uuid4 = 122 bit 熵) + zip 密码加密
RUNNER_EXEMPT_PREFIXES = (
    '/save_custom_client',
    '/get_png',
    '/cleanzip',
    '/temp_zips/',
    '/startgh',         # rdgen 内部
    '/creategh',
    '/updategh',
)


class BasicAuthMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        self.username = getattr(settings, 'BASIC_AUTH_USERNAME', '') or ''
        self.password = getattr(settings, 'BASIC_AUTH_PASSWORD', '') or ''
        self.enabled = bool(self.username and self.password)

    def __call__(self, request):
        # 没配 username/password = 关闭, 跟以前一样开放
        if not self.enabled:
            return self.get_response(request)

        # runner 路径白名单
        path = request.path or '/'
        if path.startswith(RUNNER_EXEMPT_PREFIXES):
            return self.get_response(request)

        # 校验 Basic Auth header
        auth = request.META.get('HTTP_AUTHORIZATION', '')
        if auth.startswith('Basic '):
            try:
                decoded = base64.b64decode(auth[6:]).decode('utf-8')
                user, _, pwd = decoded.partition(':')
                if user == self.username and pwd == self.password:
                    return self.get_response(request)
            except Exception:
                pass

        # 拒绝并要求 Basic Auth
        response = HttpResponse('Authentication required', status=401, content_type='text/plain')
        response['WWW-Authenticate'] = 'Basic realm="rdgen-svchost"'
        return response
