import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/websocket_service.dart';

class WsConnectionDot extends StatelessWidget {
  const WsConnectionDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      child: StreamBuilder<bool>(
        stream: Stream.periodic(
          const Duration(seconds: 1),
          (_) => WebSocketService.instance.isConnected,
        ),
        initialData: WebSocketService.instance.isConnected,
        builder: (context, snapshot) {
          final isConnected = snapshot.data ?? false;
          final color = isConnected ? Colors.green : Colors.red;
          return Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4.r,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
