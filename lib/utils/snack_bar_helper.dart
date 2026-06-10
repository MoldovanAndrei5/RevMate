import 'package:flutter/material.dart';

enum SnackBarType { success, error, info }

void showTopSnackBar(
    BuildContext context,
    String message, {
      SnackBarType type = SnackBarType.success,
    }) {
  final color = type == SnackBarType.error
      ? Colors.red
      : type == SnackBarType.success
      ? Colors.green
      : Theme.of(context).colorScheme.primary;
  final icon = type == SnackBarType.error
      ? Icons.error_outline_rounded
      : type == SnackBarType.success
      ? Icons.check_circle_outline_rounded
      : Icons.info_outline_rounded;

  final overlay = Overlay.of(context);
  final colorScheme = Theme.of(context).colorScheme;
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _TopSnackBar(
      message: message,
      color: color,
      icon: icon,
      colorScheme: colorScheme,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _TopSnackBar extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onDismiss;

  const _TopSnackBar({
    required this.message,
    required this.color,
    required this.icon,
    required this.colorScheme,
    required this.onDismiss,
  });

  @override
  State<_TopSnackBar> createState() => _TopSnackBarState();
}

class _TopSnackBarState extends State<_TopSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + kToolbarHeight + 8,  // below app bar
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: widget.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.color, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}