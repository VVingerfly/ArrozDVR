Attribute VB_Name = "File"
Option Explicit

Public Function JoinPathFile(p As String, f As String) As String
    JoinPathFile = AddSlash(p) & f
End Function

Public Function AddSlash(Directory As String) As String
    If Right$(Directory, 1) <> "\" Then Directory = Directory + "\"
    AddSlash = Directory
End Function

Public Sub RemoveSlash(Directory As String)
    If Len(Directory) > 3 And InStrRev(Directory, "\") = Len(Directory) Then Directory = Left$(Directory, Len(Directory) - 1)
End Sub

'�ֽ���ļ���Ŀ¼
Public Function CutPathFile(nStr As String, nPath As String, nFile As String)
    Dim i As Long, s As Long
    
    For i = 1 To Len(nStr)
        If Mid(nStr, i, 1) = "\" Then s = i                                     '�������һ��Ŀ¼�ָ���
    Next
    If s > 0 Then
        nPath = Left(nStr, s): nFile = Mid(nStr, s + 1)
    Else
        nPath = "": nFile = nStr
    End If
End Function

'�𼶽���Ŀ¼,�ɹ����� True
Public Function MakePath(ByVal nPath As String) As Boolean
    Dim i As Long, Path1 As String, IsPath As Boolean
    nPath = Trim(nPath)
    If Right(nPath, 1) <> "\" Then nPath = nPath & "\"
    On Error GoTo Exit1
    For i = 1 To Len(nPath)
        If Mid(nPath, i, 1) = "\" Then
            Path1 = Left(nPath, i - 1)
            If Dir(Path1, 23) = "" Then
                MkDir Path1
            Else
                IsPath = GetAttr(Path1) And 16
                If Not IsPath Then Exit Function                                '��һ��ͬ�����ļ�
            End If
        End If
    Next
    MakePath = True: Exit Function
Exit1:
End Function

'���Ŀ¼���ļ��У�����ֵ��0�����ڣ�1���ļ���2��Ŀ¼
Public Function CheckDirFile(nDirFile) As Long
    Dim nStr As String, nD As Boolean
    nStr = Dir(nDirFile, 23)
    If nStr = "" Then Exit Function
    nD = GetAttr(nDirFile) And 16
    If nD Then CheckDirFile = 2 Else CheckDirFile = 1
End Function

'����ָ��Ŀ¼�µ������ļ�������·�����ļ�������֧�����ļ��еݹ�
'����ʾ��
'  SearchFiles "C:\Program Files\WinRAR\", "*" '���������ļ�
'  SearchFiles "C:\Program Files\WinRAR\", "*.exe" '��������exe�ļ�
'  SearchFiles "C:\Program Files\WinRAR\", "*in*.exe" '�����ļ����а����� in ��exe�ļ�
Public Function SearchFiles(Path As String, FileType As String) As String()
    Dim sPath As String, numFiles As Long
    Dim saFiles() As String
    
    If Right$(Path, 1) <> "\" Then Path = Path & "\"
    
    sPath = Dir(Path & FileType) '���ҵ�һ���ļ�
    
    numFiles = 0
    Do While Len(sPath) 'ѭ����û���ļ�Ϊֹ
        ReDim Preserve saFiles(numFiles) As String
        saFiles(numFiles) = Path & sPath
        numFiles = numFiles + 1
        sPath = Dir '������һ���ļ�
        'DoEvents '�ó�����Ȩ
    Loop
    
    If numFiles Then
        SearchFiles = saFiles
    Else
        SearchFiles = Split("")
    End If
End Function

