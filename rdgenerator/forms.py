from django import forms
from PIL import Image

class GenerateForm(forms.Form):
    sh_secret_field = forms.CharField(required=False)
    #Platform
    platform = forms.ChoiceField(choices=[('windows','Windows 64Bit'),('windows-x86','Windows 32Bit'),('linux','Linux'),('android','Android'),('macos','macOS')], initial='windows')
    version = forms.ChoiceField(choices=[('master','nightly (开发版)'),('1.4.7','1.4.7'),('1.4.6','1.4.6'),('1.4.5','1.4.5'),('1.4.4','1.4.4'),('1.4.3','1.4.3'),('1.4.2','1.4.2'),('1.4.1','1.4.1'),('1.4.0','1.4.0'),('1.3.9','1.3.9'),('1.3.8','1.3.8'),('1.3.7','1.3.7'),('1.3.6','1.3.6'),('1.3.5','1.3.5'),('1.3.4','1.3.4'),('1.3.3','1.3.3')], initial='1.4.7')
    help_text="'nightly' 是含最新功能的开发版, 可能不太稳定"
    delayFix = forms.BooleanField(initial=True, required=False)

    #General
    exename = forms.CharField(label="EXE 文件名 (英文/数字, 不要空格和特殊字符)", required=True)
    appname = forms.CharField(label="应用名称 (留空用默认)", required=False)
    direction = forms.ChoiceField(widget=forms.RadioSelect, choices=[
        ('incoming', '仅被控端 (Incoming Only)'),
        ('outgoing', '仅主控端 (Outgoing Only)'),
        ('both', '双向 (主控+被控)')
    ], initial='both')
    installation = forms.ChoiceField(label="禁用安装功能", choices=[
        ('installationY', '否, 允许安装'),
        ('installationN', '是, 禁用安装')
    ], initial='installationY')
    settings = forms.ChoiceField(label="禁用设置面板", choices=[
        ('settingsY', '否, 允许进设置'),
        ('settingsN', '是, 禁用设置')
    ], initial='settingsY')
    androidappid = forms.CharField(label="自定义 Android App ID (替换默认 'com.carriez.flutter_hbb')", required=False)

    #Custom Server
    serverIP = forms.CharField(label="服务器地址 (NAS IP / 域名)", required=False)
    apiServer = forms.CharField(label="API 服务器", required=False)
    key = forms.CharField(label="服务器公钥 (Key)", required=False)
    urlLink = forms.CharField(label="自定义链接 URL", required=False)
    downloadLink = forms.CharField(label="自定义更新下载 URL", required=False)
    compname = forms.CharField(label="公司名 (版权字段)",required=False)

    #Visual
    iconfile = forms.FileField(label="自定义应用图标 (PNG 格式)", required=False, widget=forms.FileInput(attrs={'accept': 'image/png'}))
    logofile = forms.FileField(label="自定义 Logo (PNG 格式)", required=False, widget=forms.FileInput(attrs={'accept': 'image/png'}))
    privacyfile = forms.FileField(label="自定义隐私屏 (PNG 格式)", required=False, widget=forms.FileInput(attrs={'accept': 'image/png'}))
    iconbase64 = forms.CharField(required=False)
    logobase64 = forms.CharField(required=False)
    privacybase64 = forms.CharField(required=False)
    theme = forms.ChoiceField(choices=[
        ('light', '明亮'),
        ('dark', '暗黑'),
        ('system', '跟随系统')
    ], initial='system')
    themeDorO = forms.ChoiceField(choices=[('default', '默认值'),('override', '强制覆盖')], initial='default')

    #Security
    passApproveMode = forms.ChoiceField(choices=[('password','通过密码接受连接'),('click','通过点击确认接受'),('password-click','两种方式都接受')],initial='password-click')
    permanentPassword = forms.CharField(widget=forms.PasswordInput(), required=False)
    #runasadmin = forms.ChoiceField(choices=[('false','No'),('true','Yes')], initial='false')
    denyLan = forms.BooleanField(initial=False, required=False)
    enableDirectIP = forms.BooleanField(initial=False, required=False)
    #ipWhitelist = forms.BooleanField(initial=False, required=False)
    autoClose = forms.BooleanField(initial=False, required=False)

    #Permissions
    permissionsDorO = forms.ChoiceField(choices=[('default', '默认值'),('override', '强制覆盖')], initial='default')
    permissionsType = forms.ChoiceField(choices=[('custom', '自定义'),('full', '完全权限'),('view','仅看屏幕')], initial='custom')
    enableKeyboard =  forms.BooleanField(initial=True, required=False)
    enableClipboard = forms.BooleanField(initial=True, required=False)
    enableFileTransfer = forms.BooleanField(initial=True, required=False)
    enableAudio = forms.BooleanField(initial=True, required=False)
    enableTCP = forms.BooleanField(initial=True, required=False)
    enableRemoteRestart = forms.BooleanField(initial=True, required=False)
    enableRecording = forms.BooleanField(initial=True, required=False)
    enableBlockingInput = forms.BooleanField(initial=True, required=False)
    enableRemoteModi = forms.BooleanField(initial=False, required=False)
    hidecm = forms.BooleanField(initial=False, required=False)
    enablePrinter = forms.BooleanField(initial=True, required=False)
    enableCamera = forms.BooleanField(initial=True, required=False)
    enableTerminal = forms.BooleanField(initial=True, required=False)

    #Other
    removeWallpaper = forms.BooleanField(initial=True, required=False)

    defaultManual = forms.CharField(widget=forms.Textarea, required=False)
    overrideManual = forms.CharField(widget=forms.Textarea, required=False)

    #custom added features
    cycleMonitor = forms.BooleanField(initial=False, required=False)
    xOffline = forms.BooleanField(initial=False, required=False)
    removeNewVersionNotif = forms.BooleanField(initial=False, required=False)

    def clean_iconfile(self):
        print("checking icon")
        image = self.cleaned_data['iconfile']
        if image:
            try:
                # Open the image using Pillow
                img = Image.open(image)

                # Check if the image is a PNG (optional, but good practice)
                if img.format != 'PNG':
                    raise forms.ValidationError("仅支持 PNG 格式图片")

                # Get image dimensions
                width, height = img.size

                # Check for square dimensions
                if width != height:
                    raise forms.ValidationError("应用图标必须是正方形")

                return image
            except OSError:  # 处理非图片文件
                raise forms.ValidationError("无效的图标文件")
            except Exception as e: # 其他图片处理错误
                raise forms.ValidationError(f"图标处理出错: {e}")
