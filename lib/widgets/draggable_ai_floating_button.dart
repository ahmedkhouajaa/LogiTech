import 'dart:async';
import 'package:flutter/material.dart';
import 'ai_chat_modal_sheet.dart';

class DraggableAiFloatingButton extends StatefulWidget {
  final Widget child;

  const DraggableAiFloatingButton({
    super.key,
    required this.child,
  });

  @override
  State<DraggableAiFloatingButton> createState() =>
      _DraggableAiFloatingButtonState();
}

class _DraggableAiFloatingButtonState extends State<DraggableAiFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _inactivityTimer;

  // Initial position off right screen edge
  double _xPos = -1;
  double _yPos = -1;
  bool _isDragging = false;
  bool _isIdle = false;

  // Reduced size from 56.0 to 44.0 for a smaller footprint
  final double _buttonSize = 44.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_isIdle) {
      setState(() {
        _isIdle = false;
      });
    }
    _inactivityTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isIdle = true;
        });
      }
    });
  }

  void _snapToSide(double screenWidth) {
    setState(() {
      _isDragging = false;
      // Snap to whichever side is closer (left or right)
      if (_xPos < screenWidth / 2) {
        _xPos = 12.0; // Left padding
      } else {
        _xPos = screenWidth - _buttonSize - 12.0; // Right padding
      }
    });
    _resetInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Set default initial position on screen bottom right
    if (_xPos == -1 && _yPos == -1) {
      _xPos = screenWidth - _buttonSize - 12.0;
      _yPos = screenHeight * 0.70;
    }

    return Stack(
      children: [
        widget.child,

        // Floating Draggable AI Mascot Widget
        Positioned(
          left: _xPos,
          top: _yPos,
          child: GestureDetector(
            onPanStart: (_) {
              _resetInactivityTimer();
              setState(() {
                _isDragging = true;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _xPos += details.delta.dx;
                _yPos += details.delta.dy;

                // Clamp inside screen bounds
                _xPos = _xPos.clamp(4.0, screenWidth - _buttonSize - 4.0);
                _yPos = _yPos.clamp(60.0, screenHeight - _buttonSize - 60.0);
              });
            },
            onPanEnd: (_) => _snapToSide(screenWidth),
            onTap: () {
              _resetInactivityTimer();
              AiChatModalSheet.show(context);
            },
            child: AnimatedOpacity(
              opacity: _isDragging
                  ? 1.0
                  : (_isIdle ? 0.35 : 0.95), // Fades to 35% opacity after 5s of inactivity
              duration: const Duration(milliseconds: 400),
              child: AnimatedScale(
                scale: _isDragging ? 1.15 : (_isIdle ? 0.9 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulseValue = _isIdle ? 0.0 : _pulseController.value;
                    return Container(
                      width: _buttonSize,
                      height: _buttonSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFCD535), // Binance Yellow
                            Colors.amber.shade700,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isIdle
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFFFCD535).withAlpha(
                                    (100 + (pulseValue * 60)).toInt(),
                                  ),
                                  blurRadius: 8 + (pulseValue * 4),
                                  spreadRadius: 1 + (pulseValue * 2),
                                ),
                              ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Yellow Rhombus / Mascot diamond look (Binance Icon Style)
                          Transform.rotate(
                            angle: 0.785398, // 45 degrees in radians
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          // Smile Mascot Face
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 3,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 3,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 11,
                                height: 5,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.black87,
                                      width: 2.0,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
