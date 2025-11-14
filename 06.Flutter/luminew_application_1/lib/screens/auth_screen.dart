import 'package:flutter/material.dart';
import 'package.firebase_auth/firebase_auth.dart';
// 修正：導入 models 和 services 的絕對路徑
import 'package:luminew_application_1/models/app_models.dart';
import 'package:luminew_application_1/services/firebase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _userNameController =
      TextEditingController(); // 註冊用
  UserRole _selectedRole = UserRole.student;
  bool _isLoggingIn = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final userName = _userNameController.text.trim();

    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception("電子郵件和密碼不能為空");
      }

      if (_isLoggingIn) {
        // 登入
        await firebaseService.signIn(email, password);
      } else {
        // 註冊
        if (userName.isEmpty) {
          throw Exception("使用者名稱不能為空");
        }
        await firebaseService.signUp(email, password, _selectedRole, userName);
      }

      // 成功後，由 main.dart 的 authStateChanges 監聽器處理狀態更新
      // 不需要在這裡導航
    } on FirebaseAuthException catch (e) {
      String msg;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        msg = '無效的電子郵件或密碼';
      } else if (e.code == 'email-already-in-use') {
        msg = '此電子郵件已被註冊';
      } else if (e.code == 'weak-password') {
        msg = '密碼強度不足 (至少6位)';
      } else {
        msg = '驗證失敗: ${e.message}';
      }

      setState(() {
        _errorMessage = msg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '發生未知錯誤: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLoggingIn ? '登入系統' : '註冊帳號')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildRoleSelector(),
              const SizedBox(height: 20),

              if (!_isLoggingIn)
                Column(
                  children: [
                    TextField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                        labelText: '使用者名稱 (必填)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '電子郵件',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _isLoggingIn ? '密碼' : '設定密碼 (至少6位)',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _isLoggingIn ? '登入' : '註冊',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoggingIn = !_isLoggingIn;
                    _errorMessage = null;
                  });
                },
                child: Text(_isLoggingIn ? '沒有帳號？點此註冊' : '已有帳號？點此登入'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _RoleOption(
            title: '學生',
            icon: Icons.person_outline,
            isSelected: _selectedRole == UserRole.student,
            onTap: () => setState(() => _selectedRole = UserRole.student),
          ),
          _RoleOption(
            title: '教師',
            icon: Icons.school_outlined,
            isSelected: _selectedRole == UserRole.teacher,
            onTap: () => setState(() => _selectedRole = UserRole.teacher),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
