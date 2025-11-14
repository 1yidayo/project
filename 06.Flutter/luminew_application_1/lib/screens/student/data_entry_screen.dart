import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// 修正：導入 services 和 models 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';
import 'package:luminew_application_1/models/app_models.dart';

class DataEntryScreen extends StatefulWidget {
  final String userId;
  const DataEntryScreen({super.key, required this.userId});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 選擇並上傳檔案
  Future<void> _pickAndUploadFile() async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      // 1. 選擇檔案
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        final file = result.files.single;

        // 2. 上傳到 Firebase
        await firebaseService.addPortfolio(file, widget.userId);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('成功上傳檔案: ${file.name}')));
        }
      } else {
        // 使用者取消選擇
      }
    } catch (e) {
      setState(() {
        _uploadError = '上傳失敗: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // 刪除檔案
  Future<void> _deleteFile(LearningPortfolio portfolio) async {
    try {
      await firebaseService.deletePortfolio(portfolio);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已刪除檔案: ${portfolio.fileName}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刪除失敗: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('資料與履歷填寫'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '學習歷程檔案'),
            Tab(text: '基本資料 (模擬)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPortfolioTab(), _buildBasicDataTab()],
      ),
    );
  }

  // 學習歷程檔案頁
  Widget _buildPortfolioTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 上傳按鈕
          _isUploading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('上傳學習歷程檔案 (PDF/DOCX)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
          if (_uploadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _uploadError!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            '已上傳檔案列表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          // 檔案列表
          Expanded(child: _buildPortfolioList()),
        ],
      ),
    );
  }

  // 顯示從 Firebase 讀取的檔案列表
  Widget _buildPortfolioList() {
    return StreamBuilder<List<LearningPortfolio>>(
      stream: firebaseService.getPortfolios(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('尚未上傳任何檔案。'));
        }

        final portfolios = snapshot.data!;

        return ListView.builder(
          itemCount: portfolios.length,
          itemBuilder: (context, index) {
            final portfolio = portfolios[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(
                  portfolio.fileName,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '上傳於: ${portfolio.uploadedAt.toLocal().toString().substring(0, 16)}',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade600),
                  onPressed: () {
                    // 顯示確認刪除
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('確認刪除'),
                        content: Text(
                          '您確定要刪除 ${portfolio.fileName} 嗎？此操作無法復原。',
                        ),
                        actions: [
                          TextButton(
                            child: const Text('取消'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          TextButton(
                            child: const Text(
                              '刪除',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _deleteFile(portfolio);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 基本資料頁 (模擬)
  Widget _buildBasicDataTab() {
    return const Center(
      child: Text('【基本資料頁】\n學經歷、競賽經歷、自傳、申請方向等。', textAlign: TextAlign.center),
    );
  }
}
