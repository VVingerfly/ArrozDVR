VERSION 5.00
Begin VB.Form MainFrm 
   Caption         =   "Form1"
   ClientHeight    =   8175
   ClientLeft      =   60
   ClientTop       =   450
   ClientWidth     =   10425
   Icon            =   "MainFrm.frx":0000
   LinkTopic       =   "Form1"
   ScaleHeight     =   545
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   695
   StartUpPosition =   2  '��Ļ����
   Begin VB.PictureBox pic2 
      Height          =   375
      Left            =   5880
      ScaleHeight     =   315
      ScaleWidth      =   435
      TabIndex        =   3
      Top             =   2040
      Visible         =   0   'False
      Width           =   495
   End
   Begin VB.Timer Timer1 
      Left            =   6120
      Top             =   1200
   End
   Begin VB.PictureBox Picture1 
      Height          =   375
      Left            =   0
      ScaleHeight     =   315
      ScaleWidth      =   10515
      TabIndex        =   2
      Top             =   0
      Width           =   10575
   End
   Begin VB.CheckBox Check1 
      Appearance      =   0  'Flat
      BackColor       =   &H80000005&
      Caption         =   "Check1"
      ForeColor       =   &H80000008&
      Height          =   375
      Index           =   0
      Left            =   3480
      Style           =   1  'Graphical
      TabIndex        =   1
      Top             =   1200
      Width           =   1815
   End
   Begin VB.CommandButton Command1 
      Appearance      =   0  'Flat
      Caption         =   "Command1"
      Height          =   495
      Index           =   0
      Left            =   600
      TabIndex        =   0
      TabStop         =   0   'False
      Top             =   1080
      Width           =   1935
   End
   Begin VB.Image ImgRecording 
      Height          =   240
      Left            =   7560
      Picture         =   "MainFrm.frx":3BFA
      Top             =   1680
      Visible         =   0   'False
      Width           =   240
   End
End
Attribute VB_Name = "MainFrm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

'����ͷ��Ƶ��ع��ߣ��ṩ���¹��ܣ�
'1.

Private m_hCapWin As Long, m_Recording As Boolean, m_SaveDir As String, m_SaveFile As String
Private m_AutoSize As Boolean, m_AutoHide As Boolean, m_IsFullScreen As Boolean, m_TopMost As Boolean
Private m_Refresh As Boolean, m_Connected As Boolean, m_KeepAwake As Boolean
Private m_FrameRate As Long
Private m_MaxRecordMinutes As Long '���¼ʱ�䣬�Է���Ϊ��λ��С�ڵ������򲻼���¼ʱ��
Private m_MinFreeDiskSpace As Long ' ��С�������̿ռ䣬�����ֽ�Ϊ��λ��С�ڵ������򲻼����̿ռ�
Private m_HoursPerFile As Long   '�೤ʱ��ָ�һ��¼���ļ�����λΪСʱ��С�ڵ���0���Զ��ָ��ļ�
Private m_CheckRecordTimer As Long, m_FlashTrayIconCnt As Long, m_CheckDiskSpaceTimer As Long
Private m_KeepAwakeTimer As Long
Private m_CompressionClicked As Boolean

Private WithEvents m_Tray As cTray
Attribute m_Tray.VB_VarHelpID = -1

Private Const DEF_FRAME_RATE = 30 'FPS
Private Const DEF_MAX_RECORD_MINUTES = 120 'Ĭ�����¼ʱ�䣬2Сʱ
Private Const DEF_MIN_FREE_DISK_SPACE = 0 'Ĭ�ϲ����ʣ��ռ�
Private Const DEF_HOURS_PER_FILE = 1 'Ĭ��ÿСʱһ���ļ�������ָ�
Private Declare Sub InitCommonControls Lib "comctl32" ()

Private Sub StopRecord()
    m_Recording = False
    m_CheckRecordTimer = -1
    capCaptureStop m_hCapWin
    SetCaption " "
    m_Tray.SetTrayIcon Me.Icon
    m_Tray.SetTrayTip App.Title & vbCrLf & "����ͷ���¼�񹤾�"
End Sub

Private Sub StartRecord()
    Dim f As String, nDir As String, nF As String
    Dim nParms As CAPTUREPARMS
    
    '������������ѹ����
    If Not m_CompressionClicked Then
        Cmd "VideoCompression"
    End If
    
    nDir = GetSavePath()
    
    If Not MakePath(nDir) Then
        MsgBox "��ָ����λ���޷�����Ŀ¼��" & vbCrLf & nDir, vbInformation, "������Ƶ�ļ�"
        Exit Sub
    End If
    
    '�����ļ���
    nF = GetSaveFile()
    
    f = JoinPathFile(nDir, nF)
    If CheckDirFile(f) = 1 Then
        If vbNo = MsgBox("�ļ��Ѵ��ڣ����Ǵ��ļ���" & vbCrLf & f, vbInformation + vbYesNo, "��ʼ¼��") Then Exit Sub
        On Error GoTo Cuo
        SetAttr f, 0
        Kill f
        On Error GoTo 0
    End If
    
    m_Recording = False
    SetWin m_hCapWin, es_Size, , , , 1
    m_Recording = True
    SetCaption "����¼��" & nF
    ControlEnabled True
    DoEvents
    
    capCaptureGetSetup m_hCapWin, VarPtr(nParms), Len(nParms) '��ȡ����������
    
    If m_FrameRate <= 0 Then m_FrameRate = DEF_FRAME_RATE
    nParms.dwRequestMicroSecPerFrame = 1000000 / m_FrameRate  ' ��׽֡��
    nParms.fYield = 1                                                        '��һ����̨�߳���������Ƶ��׽
    nParms.fAbortLeftMouse = False                                              '�رգ�����������ֹͣ¼��Ĺ��ܡ�
    nParms.fAbortRightMouse = False                                             '�رգ���������Ҽ�ֹͣ¼��Ĺ���
    nParms.fCaptureAudio = False        '��������Ƶ
    
    capCaptureSetSetup m_hCapWin, VarPtr(nParms), Len(nParms)
    
    capFileSetCaptureFile m_hCapWin, f  '����¼�񱣴���ļ�
    
    capCaptureSequence m_hCapWin '��ʼ��׽
    
    m_CheckRecordTimer = 2
    m_Tray.SetTrayTip App.Title & vbCrLf & "����¼����..."
    Exit Sub
Cuo:
    MsgBox "�޷�д�ļ���" & vbCrLf & vbCrLf & f, vbInformation, "¼�� - ����"
End Sub

'���ı�����ʾ�û�����Ҫ�����Ŀ¼
Private Sub AskForDir()
    Dim nStr As String
    m_SaveDir = GetSavePath()
    nStr = "����¼�񱣴���ļ��С�" & vbCrLf & "���롰<>����ʾʹ��Ĭ���ļ��У�" & vbCrLf & App.Path & "\videos"
    nStr = Trim(InputBox(nStr, "¼�񱣴���ļ���", m_SaveDir))
    If Len(nStr) = 0 Then Exit Sub
    m_SaveDir = nStr
End Sub

'���ı�����ʾ�û�����Ҫ������ļ���
Private Sub AskForFile()
    Dim nStr As String, nF As String
    
    nF = String(255, " ")
    capFileGetCaptureFile m_hCapWin, VarPtr(nF), Len(nF)
    
    nF = GetStrLeft(nF, vbNullChar)
    
    If Trim(m_SaveFile) = "" Then m_SaveFile = "<>"
    nStr = "����¼�񱣴���ļ���(����·��)��" & vbCrLf & "���롰<>����ʾʹ��Ĭ���ļ���������-ʱ��.��չ��"
    nStr = Trim(InputBox(nStr, "¼�񱣴���ļ���", m_SaveFile))
    If Len(nStr) = 0 Then Exit Sub
    m_SaveFile = nStr
End Sub

Private Sub AskForFrameRate()
    Dim nStr As String, nRate As Long
    nStr = Trim(InputBox("����¼���Ԥ����֡��FPS��", "֡��", m_FrameRate))
    If Len(nStr) = 0 Then Exit Sub
    If IsNumeric(nStr) Then
        nRate = CLng(nStr)
        If nRate > 0 Then
            m_FrameRate = nRate
        End If
    End If
End Sub

Private Sub AskForMaxRecordTime()
    Dim nStr As String, nTime As Long
    nStr = Trim(InputBox("����¼��������ʱ�䣨���ӣ���С�ڵ���������ʱ�䡣", "¼����ʱ��", m_MaxRecordMinutes))
    If Len(nStr) = 0 Then Exit Sub
    If IsNumeric(nStr) Then
        nTime = CLng(nStr)
        m_MaxRecordMinutes = nTime
    End If
End Sub

Private Sub AskForMinFreeDiskSpace()
    Dim nStr As String, nSpace As Long
    nStr = Trim(InputBox("���ô��̵���С����ʣ��ռ䣨���ֽڣ���С�ڵ������򲻼��ʣ��ռ䡣" & vbCrLf & Left$(GetSavePath(), 1) & _
        " �̵�ǰʣ��ռ䣺" & CLng(GetDiskFreeSpace(Left$(GetSavePath(), 3)) / 100) & "MB", "���̱����ռ�", m_MinFreeDiskSpace))
    If Len(nStr) = 0 Then Exit Sub
    If IsNumeric(nStr) Then
        nSpace = CLng(nStr)
        m_MinFreeDiskSpace = nSpace
    End If
End Sub

Private Sub AskForHoursPerFile()
    Dim nStr As String, nHours As Long
    nStr = Trim(InputBox("���÷ָ�¼���ļ���ʱ������Сʱ����С�ڵ��������Զ��ָ��ļ���" & vbCrLf & "ע�⣺�����������ʱ�ָ��ļ������Ե�һ���ļ��ĳ���С�ڵ����趨��ʱ������" _
        , "�Զ��ָ��ļ�", m_HoursPerFile))
    If Len(nStr) = 0 Then Exit Sub
    If IsNumeric(nStr) Then
        nHours = CLng(nStr)
        m_HoursPerFile = nHours
    End If
End Sub

Private Function GetStrLeft(nStr As String, Fu As String) As String
    'ȥ�� Fu ��������ַ�
    Dim s As Long
    s = InStr(nStr, Fu)
    If s > 0 Then GetStrLeft = Left(nStr, s - 1) Else GetStrLeft = nStr
End Function

Private Sub form_Initialize()
InitCommonControls

End Sub

Private Sub Form_Load()
    Dim W As Long, H As Long
    
    SetCaption ""
    
    Me.ScaleMode = 3
    Picture1.ScaleMode = 3
    Picture1.BorderStyle = 0
    Set Command1(0).Container = Picture1
    Set Check1(0).Container = Picture1
    
    m_MaxRecordMinutes = DEF_MAX_RECORD_MINUTES
    m_FrameRate = DEF_FRAME_RATE
    m_MinFreeDiskSpace = DEF_MIN_FREE_DISK_SPACE
    m_HoursPerFile = DEF_HOURS_PER_FILE
    m_TopMost = False
    m_IsFullScreen = False
    m_CheckRecordTimer = -1
    m_CompressionClicked = False
    
    ReadSaveSetting False                                                            '��ȡ�û�����
    
    'װ������ؼ�
    AddControl Command1, "��", "Connect", "��������ͷ"
    AddControl Command1, "��", "DisConnect", "�Ͽ�������ͷ������"
    AddControl Command1, "-"
    AddControl Command1, "Դ", "VideoSource", "ѡ����ƵԴ"
    AddControl Command1, "��", "VideoFormat", "���ã���Ƶ��ʽ���ֱ���"
    AddControl Command1, "��", "VideoDisplay", "��Ƶ��ʾ�Ի���ĳЩ�Կ���֧�ִ˹��ܡ�"
    AddControl Command1, "-"
    AddControl Command1, "��", "AskForDir", "����¼���ļ�������ļ��С�Ĭ��Ϊ����������Ŀ¼�µġ�videos���ļ���"
    AddControl Command1, "��", "AskForFile", "¼�񱣴���ļ�����Ĭ��Ϊ��ʱ��-���.��չ��"
    AddControl Command1, "ѹ", "VideoCompression", "������Ƶ¼���ļ���ѹ����ʽ"
    AddControl Command1, "֡", "FrameRate", "����¼��֡��"
    AddControl Command1, "ʱ", "MaxRecordTime", "���������¼��ʱ��"
    AddControl Command1, "ʣ", "MinFreeDiskSpace", "������С���̿ռ䣬���̿ռ�С�ڴ�ֵ���Զ�ɾ���ϼ�¼"
    AddControl Command1, "��", "HoursPerFile", "����¼���ļ��ķָ�ʱ��"
    AddControl Command1, "-"
    AddControl Command1, "¼", "Record", "��ʼ¼��"
    AddControl Command1, "ͣ", "StopRecord", "ֹͣ¼��"
    AddControl Command1, "ͼ", "CopyImg", "����ǰͼ���Ƶ�������"
    AddControl Command1, "-"
    AddControl Command1, "ȫ", "ToggleFullScreen", "�л���ȫ��/����"
    AddControl Command1, "��", "Exit", "�رգ��˳�����"
    
    AddControl(Check1, "��", "AutoSize", "��Ƶ�����Ƿ����������Զ��ı��С").Value = IIf(m_AutoSize, 1, 0)
    AddControl(Check1, "��", "AutoHide", "��С��ʱ�Զ�����������").Value = IIf(m_AutoHide, 1, 0)
    AddControl(Check1, "��", "KeepAwake", "��ֹϵͳ�������������").Value = IIf(m_KeepAwake, 1, 0)
    AddControl(Check1, "��", "TopMost", "���ô����ö�").Value = IIf(m_TopMost, 1, 0)
    
    ListControl Command1, Command1(0).Height * 0.1                                   '��������ؼ�
    W = Command1(Command1.UBound).Left + Command1(Command1.UBound).Width * 2
    ListControl Check1, W                                                            '��������ؼ�
    Picture1.Height = Command1(0).Height * 1.2
    
    m_Refresh = True
    
    CreateCapWin         '������Ƶ����
    
    ControlEnabled True
    
    Timer1.Interval = 600
    Timer1.Enabled = True
    
    Set m_Tray = New cTray
    m_Tray.AddTrayIcon pic2
    m_Tray.SetTrayIcon Me.Icon
    m_Tray.SetTrayTip App.Title & vbCrLf & "����ͷ���¼�񹤾�"
End Sub

Private Sub Form_QueryUnload(Cancel As Integer, UnloadMode As Integer)
    If m_Recording Then StopRecord
    Cmd "DisConnect"                                                            '�Ͽ�����ͷ����
    SetWin m_hCapWin, es_Close
    ReadSaveSetting True                                                      '�����û�����
    m_Tray.DelTrayIcon
End Sub

Private Sub Form_Resize()
    Picture1.Move 0, 0, Me.ScaleWidth, Command1(0).Height * 1.2
    If m_AutoSize Then SetWin m_hCapWin, es_Size                '��Ƶ�Ӵ������������Զ��ı��С
    If m_AutoHide And Me.WindowState = vbMinimized Then Me.Hide
End Sub

Private Sub m_Tray_MouseClick(ByVal Button As Long, ByVal DBClick As Boolean)
    If DBClick = True Or Me.WindowState = vbMinimized Then
        ToggleWindowState
    End If
End Sub

'��ȫ��״̬�£��������ƶ�����Ļ���ˣ��򵯳�������
Private Sub Timer1_Timer()
    Dim nP As POINTAPI, x As Long, y As Long, H As Long
    Dim dNow As Date, nHour As Long, nMinute As Long, nSecond As Long
    Dim nStatus As CAPSTATUS, crFreeSpace As Currency
    
    '�ж�¼���Ƿ��Ѿ��쳣��ֹ
    If m_CheckRecordTimer = 0 Then
        If capGetStatus(m_hCapWin, VarPtr(nStatus), Len(nStatus)) Then
            If nStatus.fCapturingNow = False And m_Recording Then
                Cmd "StopRecord"
                m_Tray.SetTrayMsgbox "¼������Ѿ���ֹ��������ֹԭ��", NIIF_WARNING, "��ֹ"
            End If
        End If
        m_CheckRecordTimer = 2
    ElseIf m_CheckRecordTimer > 0 Then
        m_CheckRecordTimer = m_CheckRecordTimer - 1
    End If
    
    If m_Recording Then
        '��˸����ͼ��
        If m_FlashTrayIconCnt > 0 Then
            m_Tray.SetTrayIcon Me.Icon
            m_FlashTrayIconCnt = 0
        Else
            m_Tray.SetTrayIcon ImgRecording.Picture
            m_FlashTrayIconCnt = 1
        End If
        
        '����ʱ�ŷָ��ļ��������Ҫ�Ļ�
        If m_HoursPerFile > 0 Then
            dNow = Now
            nMinute = Minute(dNow)
            nSecond = Second(dNow)
            If nMinute = 0 And nSecond = 0 Then  '����
                nHour = Hour(dNow)
                If nHour Mod m_HoursPerFile = 0 Then
                    StopRecord
                    StartRecord
                    If m_MaxRecordMinutes > 0 Then '�ָ��ļ���ͬʱɾ�������ļ�
                        DeleteExpiredFiles
                    End If
                End If
            End If
        End If
        
        '���ʣ����̿ռ�
        If m_MinFreeDiskSpace > 0 Then
            m_CheckDiskSpaceTimer = m_CheckDiskSpaceTimer + 1
            If m_CheckDiskSpaceTimer > 101 Then
                m_CheckDiskSpaceTimer = 0
                crFreeSpace = GetDiskFreeSpace(Left$(GetSavePath(), 3))
                If CLng(crFreeSpace / 100) < m_MinFreeDiskSpace Then
                    DeleteOldestFile
                End If
            End If
        End If
    End If
    
    '��ֹ���ߺʹ���
    If m_KeepAwake Then
        m_KeepAwakeTimer = m_KeepAwakeTimer + 1
        If m_KeepAwakeTimer > 210 Then
            m_KeepAwakeTimer = 0
            ResetIdleTime
        End If
    End If
    
    '�����Ǵ���ȫ��״̬�µĹ�������ʾ������
    If Not m_IsFullScreen Then Exit Sub
    
    GetCursorPos nP
    x = nP.x - Me.Left / Screen.TwipsPerPixelX
    y = nP.y - Me.Top / Screen.TwipsPerPixelY
    
    H = Me.Height / Screen.TwipsPerPixelY - Me.ScaleHeight                      '���ڱ������߶�
    If y > -1 And y < H + Picture1.Height Then
        If Picture1.Visible Then Exit Sub
        Picture1.Visible = True
    Else
        If Not Picture1.Visible Then Exit Sub
        Picture1.Visible = False
    End If
    SetWin m_hCapWin, es_Size
    
End Sub

Private Sub SetCaption(Optional nCap As String)
    If nCap <> "" Then Me.Tag = Trim(nCap)
    If m_IsFullScreen Then                                                        'ȫ����ʽ
        Me.Caption = ""
    Else                                                                        '���ڷ�ʽ
        If Me.Tag = "" Then Me.Caption = "ArrozDVR" Else Me.Caption = "ArrozDVR - " & Me.Tag
    End If
End Sub

Private Sub Check1_Click(Index As Integer)
    Dim nTag As String, TF As Boolean
    
    If Not m_Refresh Then Exit Sub
    nTag = Check1(Index).Tag
    TF = Check1(Index).Value = 1
    Select Case LCase(nTag)
        Case LCase("AutoSize")
            m_AutoSize = TF
            SendMessage m_hCapWin, WM_CAP_SET_SCALE, m_AutoSize, 0                   'Ԥ��ͼ���洰���Զ�����
            Call SetWin(m_hCapWin, es_Size)
        Case LCase("AutoHide")
            m_AutoHide = TF
        Case LCase("KeepAwake")
            m_KeepAwake = TF
        Case LCase("TopMost")
            ToggleTopMost
    End Select
End Sub

Private Sub Command1_Click(Index As Integer)
    SendMessage Command1(Index).hWnd, WM_KILLFOCUS, 0, 0
    Cmd Command1(Index).Tag
End Sub

Private Sub Cmd(nCmd As String)
    Select Case LCase(nCmd)
        Case LCase("Connect"):
            CapConnect                             ' ��������ͷ
        Case LCase("DisConnect"):
            m_Connected = False
            capDriverDisconnect m_hCapWin '�Ͽ�����ͷ����
        Case LCase("VideoSource"):
            capDlgVideoSource m_hCapWin '�Ի�����ƵԴ
        Case LCase("VideoFormat"):
            capDlgVideoFormat m_hCapWin
            SetWin m_hCapWin, es_Size '��ʾ�Ի�����Ƶ��ʽ,�ֱ���
        Case LCase("VideoDisplay"):
            capDlgVideoDisplay m_hCapWin '�Ի�����Ƶ��ʾ��ĳЩ�Կ���֧�֣�
        Case LCase("AskForDir"):
            AskForDir
        Case LCase("AskForFile"):
            AskForFile
        Case LCase("VideoCompression"):
            m_CompressionClicked = True
            capDlgVideoCompression m_hCapWin '�Ի�����Ƶѹ��
        Case LCase("FrameRate"):
            AskForFrameRate
        Case LCase("MaxRecordTime"):
            AskForMaxRecordTime
        Case LCase("MinFreeDiskSpace"):
            AskForMinFreeDiskSpace
        Case LCase("HoursPerFile"):
            AskForHoursPerFile
        Case LCase("Record"):
            StartRecord
        Case LCase("StopRecord"):
            StopRecord
        
        Case LCase("CopyImg"):
            CaptureImg
        Case LCase("ToggleFullScreen"):
            ToggleFullScreen
        Case LCase("Exit"):
            Unload Me
            Exit Sub
    End Select
    
    ControlEnabled True
End Sub

'ȫ���л�
Public Sub ToggleFullScreen()
    m_IsFullScreen = Not m_IsFullScreen
    Picture1.Visible = Not m_IsFullScreen
    If m_IsFullScreen Then Me.BorderStyle = 0 Else Me.BorderStyle = 2
    Call SetCaption("")
    
    If m_IsFullScreen Then                                                        'ȫ����ʽ
        Me.WindowState = 2
        Check1(KjIndex(Check1, "AutoSize")).Value = 1                           '�л�������Ƶ�������������Զ��ı��С
    Else                                                                        '���ڷ�ʽ
        Me.WindowState = 0
    End If
    Check1(KjIndex(Check1, "AutoSize")).Enabled = Not m_IsFullScreen
End Sub

Public Sub ToggleTopMost()
    If m_TopMost Then
        SetWindowPos Me.hWnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE Or SWP_NOSIZE
    Else
        SetWindowPos Me.hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE Or SWP_NOSIZE
    End If
    m_TopMost = Not m_TopMost
End Sub

'��ȡ��Ƶ�Ĵ�С�ߴ�
Private Sub VideoSize(W As Long, H As Long)
    Dim nInf As BitMapInfo
    capGetVideoFormat m_hCapWin, VarPtr(nInf), Len(nInf)
    W = nInf.bmiHeader.biWidth
    H = nInf.bmiHeader.biHeight
End Sub

Private Function AddControl(Kj As Object, nCap As String, Optional nTag As String, Optional nNote As String) As Control
    'װ��һ������ؼ�
    Dim i As Long
    
    i = Kj.UBound
    If Kj(i).Tag <> "" Then i = i + 1: Load Kj(i)
    On Error Resume Next
    Kj(i).Caption = nCap
    If nTag = "" Then Kj(i).Tag = Kj(i).Name & "-" & i Else Kj(i).Tag = nTag
    If Len(nNote) > 0 Then Kj(i).ToolTipText = nNote
    Set AddControl = Kj(i)
End Function

Private Sub ListControl(Kj As Object, L As Long)
    '��������ؼ�
    Dim i As Long, H1 As Long, T As Long, W As Long
    
    H1 = Picture1.TextHeight("A"): T = H1 * 0.25: W = H1 * 2
    For i = Kj.lBound To Kj.UBound
        If Kj(i).Caption = "-" Then
            L = L + H1: Kj(i).Visible = False
        Else
            Kj(i).Move L, T, W, W: Kj(i).Visible = True
            L = L + W
        End If
    Next
End Sub

Private Function KjIndex(Kj As Object, nTag As String) As Long
    Dim i As Long
    For i = Kj.lBound To Kj.UBound
        If LCase(Kj(i).Tag) = LCase(nTag) Then KjIndex = i: Exit Function
    Next
    KjIndex = -1
End Function

Private Sub ControlEnabled(Optional nEnabled As Boolean)
    Dim Kj, TF As Boolean, nType As String
    On Error Resume Next
    For Each Kj In Me.Controls
        nType = LCase(TypeName(Kj))
        If nType = "commandbutton" Or nType = "checkbox" Then
            Kj.Enabled = nEnabled
        End If
    Next
    
    Command1(KjIndex(Command1, "ToggleFullScreen")).Enabled = True
    Command1(KjIndex(Command1, "Exit")).Enabled = True
    Check1(KjIndex(Check1, "AutoSize")).Enabled = Not m_IsFullScreen
    If Not nEnabled Then Exit Sub
    
    TF = m_Connected
    If m_Recording Then TF = False
    
    Command1(KjIndex(Command1, "Connect")).Enabled = Not TF
    Command1(KjIndex(Command1, "DisConnect")).Enabled = TF                      '��ť������ͷ����״̬�ſ���
    
    Command1(KjIndex(Command1, "VideoSource")).Enabled = TF
    Command1(KjIndex(Command1, "VideoFormat")).Enabled = TF
    Command1(KjIndex(Command1, "VideoDisplay")).Enabled = TF
    
    Command1(KjIndex(Command1, "VideoCompression")).Enabled = TF
    Command1(KjIndex(Command1, "Record")).Enabled = TF
    Command1(KjIndex(Command1, "StopRecord")).Enabled = TF
    Command1(KjIndex(Command1, "CopyImg")).Enabled = TF
    
    Command1(KjIndex(Command1, "FrameRate")).Enabled = Not m_Recording
    
    If Not m_Recording Then Exit Sub
    Command1(KjIndex(Command1, "Record")).Enabled = False
    Command1(KjIndex(Command1, "StopRecord")).Enabled = True
    Command1(KjIndex(Command1, "AskForFile")).Enabled = False
    Command1(KjIndex(Command1, "AskForDir")).Enabled = False
End Sub

Private Sub CreateCapWin()
    '������Ƶ����
    Dim nStyle As Long, s As Long
    Dim lpszName As String * 128
    Dim lpszVer As String * 128
    
    Do
        If capGetDriverDescriptionA(s, lpszName, 128, lpszVer, 128) = 0 Then Exit Do '��������������ƺͰ汾��Ϣ
        s = s + 1
    Loop
    nStyle = WS_CHILD + WS_VISIBLE + WS_THICKFRAME  ' + WS_CAPTION  '�Ӵ���+�ɼ�+������+�߿�
    If m_hCapWin <> 0 Then Exit Sub
    m_hCapWin = capCreateCaptureWindow("myDVR", nStyle, 0, 0, 640, 480, Me.hWnd, 0)
    If m_hCapWin = 0 Then Exit Sub
    SetWin m_hCapWin, es_Move, 0, Command1(0).Top + Command1(0).Height + 3, 640, 480
    capSetCallbackOnError m_hCapWin, AddressOf MyErrorCallback
End Sub

'������ͷ
Private Sub CapConnect()
    Dim d As Long
    d = capDriverConnect(m_hCapWin, 0)                      '����һ����Ƶ�������ɹ�������(1)
    capPreviewScale m_hCapWin, m_AutoSize                       'Ԥ��ͼ���洰���Զ�����
    capPreviewRate m_hCapWin, m_FrameRate                         '����Ԥ����ʾƵ��
    capPreview m_hCapWin, 1                              '������������1-Ԥ��ģʽ��Ч,0-Ԥ��ģʽ��Ч
    
    m_Connected = True
    SetWin m_hCapWin, es_Size                                               '������Ƶ����Ϊ��ȷ�Ĵ�С
End Sub

'���ô��ڵ�״̬
Private Sub SetWin(hWnd As Long, nSet As enWinSet, Optional ByVal nLeft As Long, Optional ByVal nTop As Long, Optional ByVal nWidth As Long, Optional ByVal nHeight As Long)
    Dim hWndZOrder As Long, wFlags As Long
    
    If hWnd = 0 Then Exit Sub
    Select Case nSet
    Case es_Close: SendMessage hWnd, WM_CLOSE, 0, 0: Exit Sub
    Case es_Hide: wFlags = SWP_NOMOVE + SWP_NOSIZE + SWP_NOZORDER + SWP_HIDEWINDOW '����
    Case es_Show: hWndZOrder = HWND_TOP: wFlags = SWP_NOSIZE + SWP_SHOWWINDOW   '��ʾ
    Case es_Move
        hWndZOrder = HWND_TOP: wFlags = SWP_NOACTIVATE + SWP_NOSIZE
    Case es_Size
        hWndZOrder = HWND_TOP: wFlags = SWP_NOACTIVATE
        If m_Recording Then wFlags = wFlags + SWP_NOSIZE '¼��״̬�¸ı���Ƶ���ڴ�С����ʱ�����Ī������Ĵ���
        
        nLeft = 0
        If Picture1.Visible Then nTop = Picture1.Height + 3
        If m_AutoSize Then
            nWidth = Me.ScaleWidth - nLeft
            nHeight = IIf(nHeight = 1, Me.ScaleHeight, Me.ScaleHeight - nTop)
        Else
            VideoSize nWidth, nHeight                                     '��ȡ��Ƶ��ʵ�ʴ�С
        End If
        If nWidth < 20 Or nHeight < 20 Then Exit Sub
    End Select
    
    SetWindowPos hWnd, hWndZOrder, nLeft, nTop, nWidth, nHeight, wFlags
End Sub

Private Sub CaptureImg()
    Clipboard.Clear
    capEditCopy m_hCapWin '����ǰͼ���Ƶ�������
    
    m_Tray.SetTrayMsgbox "ͼ���Ѿ����Ƶ��˼����塣", NIIF_NONE, "���Ƴɹ�"
End Sub

'���û��ȡ�û�������Ϣ
Private Sub ReadSaveSetting(IsSave As Boolean)
    Dim sTitle As String
    sTitle = App.Title
    If IsSave Then
        SaveSetting sTitle, "Setting", "AutoSize", m_AutoSize
        SaveSetting sTitle, "Setting", "AutoHide", m_AutoHide
        SaveSetting sTitle, "Setting", "KeepAwake", m_KeepAwake
        SaveSetting sTitle, "Setting", "SavePath", m_SaveDir
        SaveSetting sTitle, "Setting", "SaveFile", m_SaveFile
        SaveSetting sTitle, "Setting", "FrameRate", m_FrameRate
        SaveSetting sTitle, "Setting", "MaxRecordMinutes", m_MaxRecordMinutes
        SaveSetting sTitle, "Setting", "MinFreeDiskSpace", m_MinFreeDiskSpace
        SaveSetting sTitle, "Setting", "HoursPerFile", m_HoursPerFile
        SaveSetting sTitle, "Setting", "TopMost", m_TopMost
    Else
        m_AutoSize = GetSetting(sTitle, "Setting", "AutoSize", True)
        m_AutoHide = GetSetting(sTitle, "Setting", "AutoHide", False)
        m_KeepAwake = GetSetting(sTitle, "Setting", "KeepAwake", False)
        m_SaveDir = GetSetting(sTitle, "Setting", "SavePath", "")
        m_SaveFile = GetSetting(sTitle, "Setting", "SaveFile", "")
        m_FrameRate = GetSetting(sTitle, "Setting", "FrameRate", DEF_FRAME_RATE)
        m_MaxRecordMinutes = GetSetting(sTitle, "Setting", "MaxRecordMinutes", DEF_MAX_RECORD_MINUTES)
        m_MinFreeDiskSpace = GetSetting(sTitle, "Setting", "MinFreeDiskSpace", DEF_MIN_FREE_DISK_SPACE)
        m_HoursPerFile = GetSetting(sTitle, "Setting", "HoursPerFile", DEF_HOURS_PER_FILE)
        m_TopMost = GetSetting(sTitle, "Setting", "TopMost", False)
    End If
End Sub

'��ȡ��ǰҪ�����Ŀ¼
Private Function GetSavePath() As String
    '���·�������ڣ��ó���Ŀ¼����Ŀ¼videos��ʹ��Ĭ���ļ��������-�¼�.avi
    GetSavePath = Trim(m_SaveDir)
    If Len(GetSavePath) = 0 Or GetSavePath = "<>" Or GetSavePath = "<Ĭ��>" Or GetSavePath = "<Default>" Then
        GetSavePath = JoinPathFile(App.Path, "videos\")
    End If
End Function

'��ȡ��ǰҪ������ļ���
Private Function GetSaveFile() As String
    GetSaveFile = Trim(m_SaveFile)
    If Len(GetSaveFile) = 0 Or GetSaveFile = "<>" Or GetSaveFile = "<Ĭ��>" Or GetSaveFile = "<Default>" Then
        GetSaveFile = Format(Now, "yyyy-mm-dd-hh_mm_ss") & ".avi"
    End If
    If InStr(GetSaveFile, ".") <= 0 Then GetSaveFile = GetSaveFile & ".avi"
End Function

'ɾ��һ��ʱ��ǰ����Ƶ¼���ļ�
Private Sub DeleteExpiredFiles()
    Dim sFiles() As String, i As Long, s As String, sTime As String, numFileDeleted As Long
    
    sFiles = SearchFiles(GetSavePath(), "????-??-??-??_??_??.avi") 'yyyy-mm-dd-hh_mm_ss
    
    For i = 0 To UBound(sFiles)
        s = sFiles(i)
        If LCase(Right$(s, 4)) = ".avi" Then
            s = Left$(Right$(s, 23), 19)
            sTime = Left$(s, 10) & " " & Replace(Right$(s, 8), "_", ":")
            
            If DateDiff("n", CDate(sTime), Now) > m_MaxRecordMinutes Then
                On Error Resume Next
                Kill sFiles(i)
                numFileDeleted = numFileDeleted + 1
                On Error GoTo 0
            End If
        End If
    Next
    
    If numFileDeleted > 0 Then
        m_Tray.SetTrayMsgbox "�Ѿ�ɾ���� " & numFileDeleted & "�����ڵ�¼���ļ���", NIIF_INFO
    End If
End Sub

'ɾ��һ�����ϵ��ļ�
Private Sub DeleteOldestFile()
    Dim sFiles() As String, i As Long, s As String
    Dim sTime As String, nDiff As Long, nMaxDiff As Long, sOldestFile As String
    
    sFiles = SearchFiles(GetSavePath(), "????-??-??-??_??_??.avi") 'yyyy-mm-dd-hh_mm_ss
    If UBound(sFiles) <= 0 Then Exit Sub '�����������ļ��ſ�ɾ�����ϵ�
    
    For i = 0 To UBound(sFiles)
        s = sFiles(i)
        If LCase(Right$(s, 4)) = ".avi" Then
            s = Left$(Right$(s, 23), 19)
            sTime = Left$(s, 10) & " " & Replace(Right$(s, 8), "_", ":")
            
            nDiff = DateDiff("s", CDate(sTime), Now)
            If nDiff > nMaxDiff Then
                nMaxDiff = nDiff
                sOldestFile = sFiles(i)
            End If
        End If
    Next
    
    If Len(sOldestFile) Then
        On Error Resume Next
        Kill sOldestFile
        On Error GoTo 0
        'm_Tray.SetTrayMsgbox "�Ѿ��ɹ�ɾ����һ�����ϵ��ļ���", NIIF_INFO, "ɾ���ļ�", 1000
    End If
End Sub

Private Function ToggleWindowState()
    If Me.WindowState <> vbMinimized Then
        Me.WindowState = vbMinimized
        'Me.Hide
    Else
        Me.WindowState = vbNormal
        Me.Show
    End If
End Function

