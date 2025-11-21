import 'dart:async'; // これは正しいインポート
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _uiHidden = false;

  @override
  void initState() {
    super.initState();
    // 初期メッセージ（Web版と同等）
    _messages.add(
      const _ChatMessage(
        text: 'おかえりなさい。',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _fetchMiyuReply(String userText) async {
    // あなたのPCのローカルプロキシ
    final url = Uri.parse('http://192.168.1.9:3000/grok');

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': userText,
        }),
      );

      if (res.statusCode != 200) {
        // ignore: avoid_print
        print('proxy error status: ${res.statusCode} / ${res.body}');
        return null;
      }

      final data = jsonDecode(res.body);
      final reply = data['reply'] as String?;
      // ignore: avoid_print
      print('miyu reply: $reply');
      return reply;
    } catch (e) {
      // ignore: avoid_print
      print('proxy error: $e');
      return null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0, // reverse: true のため 0 が最下部
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    if (_isSending) return;

    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );
    });
    _inputController.clear();
    _scrollToBottom();

    _isSending = true;
    setState(() {});
    try {
      // 「……」を一旦表示（簡易タイピングインジケータ）
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: '……',
            isUser: false,
          ),
        );
      });
      _scrollToBottom();

      final userText = text;
      final replyText = await _fetchMiyuReply(userText);

      // 「……」を差し替え
      if (_messages.isNotEmpty &&
          _messages.last.isUser == false &&
          _messages.last.text == '……') {
        _messages.removeLast();
      }

      if (replyText != null && replyText.isNotEmpty) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: replyText,
              isUser: false,
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            const _ChatMessage(
              text: '（ごめん、うまく返事できなかった…）',
              isUser: false,
            ),
          );
        });
      }
      _scrollToBottom();
    } finally {
      _isSending = false;
      setState(() {});
    }
  }

  Future<void> _handleHeart() async {
    if (_isSending) return;

    String text = _inputController.text.trim();
    if (text.isEmpty) {
      text = 'なにかおまかせでお願い';
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          text: '❤ $text',
          isUser: true,
          isImageEvent: true,
        ),
      );
    });
    _inputController.clear();
    _scrollToBottom();

    _isSending = true;
    setState(() {});
    try {
      // 画像イベントでも一旦「……」
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: '……',
            isUser: false,
          ),
        );
      });
      _scrollToBottom();

      // いまは通常テキストと同じエンドポイントに送る
      final replyText = await _fetchMiyuReply(text);

      if (_messages.isNotEmpty &&
          _messages.last.isUser == false &&
          _messages.last.text == '……') {
        _messages.removeLast();
      }

      if (replyText != null && replyText.isNotEmpty) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: replyText,
              isUser: false,
              // 将来ここで imageUrl も追加予定
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            const _ChatMessage(
              text: '（ごめん、うまく返事できなかった…）',
              isUser: false,
            ),
          );
        });
      }
      _scrollToBottom();
    } finally {
      _isSending = false;
      setState(() {});
    }
  }

  void _toggleUiHidden() {
    setState(() {
      _uiHidden = !_uiHidden;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // UI非表示中にどこかタップで復帰
          if (_uiHidden) {
            setState(() {
              _uiHidden = false;
            });
          }
        },
        child: Stack(
          children: [
            const _AvatarBackground(),
            if (!_uiHidden)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: _buildMessageList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusText(),
                      const SizedBox(height: 4),
                      _buildInputArea(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Spacer(),
        // 将来的なアバター変更ボタンのプレースホルダ（UIだけ）
        
        const SizedBox(width: 8),
        IconButton(
          onPressed: _toggleUiHidden,
          icon: const Icon(
            Icons.close,
            size: 20,
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            shape: const CircleBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true, // 下から積む
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[_messages.length - 1 - index];
        return _MessageBubble(message: msg);
      },
    );
  }

  Widget _buildStatusText() {
    String text = '';
    if (_isSending) {
      text = '考え中…';
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    color: Colors.transparent,  // 背景を透明に設定
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, // ギャラリーアイコンを左寄せ
      children: [
        Align(
          alignment: Alignment.centerLeft,  // 左寄せにする
          child: IconButton(
            onPressed: () {
              // ギャラリーアイコンの処理
            },
            icon: const Icon(Icons.image_outlined),
            color: Colors.white70,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ),
        const SizedBox(height: 8), // ギャラリーアイコンとテキストボックスの間隔
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 2,  // 2行に戻す
                maxLines: 5,  // 最大5行まで表示
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'ここにメッセージを書いてね…',
                  hintStyle: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,  // 半透明背景を削除
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _isSending ? null : _handleSend,
              icon: const Icon(Icons.send_rounded),
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _isSending ? null : _handleHeart,
              icon: const Text(
                '❤',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


}

class _AvatarBackground extends StatelessWidget {
  const _AvatarBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/miyu_bg.png',
            width: double.infinity,  // 横幅に合わせる
            fit: BoxFit.fitWidth,    // 横幅に合わせる（画像が拡大しないように）
          ),
        ),
      ],
    );
  }
}


class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isImageEvent;
  final String? imageUrl;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isImageEvent = false,
    this.imageUrl,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;

    final Alignment alignment =
        isUser ? Alignment.centerRight : Alignment.centerLeft;

    final Color bubbleColor = isUser
        ? const Color.fromRGBO(160, 200, 255, 0.15)
        : const Color.fromRGBO(255, 180, 210, 0.15);

    final Color textColor = isUser
        ? const Color(0xFFE9F3FF)
        : const Color(0xFFFFE9F3);

    final BorderRadius radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isUser ? 14 : 2),
      bottomRight: Radius.circular(isUser ? 2 : 14),
    );

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        constraints: const BoxConstraints(
          maxWidth: 280,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (message.imageUrl != null)
              Padding(
  padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
