import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene_manipulation/flutter_scene_manipulation.dart';

void main() => runApp(const MaterialApp(home: CubeView()));

class CubeView extends StatefulWidget {
  const CubeView({super.key});

  @override
  State<CubeView> createState() => _CubeViewState();
}

class _CubeViewState extends State<CubeView> {
  final Scene scene = Scene();

  final camera = Node()
    ..addComponent(CameraComponent(activateOnMount: true))
    ..addComponent(
      OrbitCameraController(target: vm.Vector3.zero(), distance: 8),
    );

  ManipulationOptions currentOption_ = ManipulationOptions.freedrag;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }

    scene.add(
      ManipulatableNode(
        options: {
          ManipulationOptions.freedrag,
          ManipulationOptions.scalable,
          ManipulationOptions.rotatable,
          ManipulationOptions.translatable,
        },
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(0.1, 0.1, 0.1)),
          PhysicallyBasedMaterial(),
        ),
      ),
    );
    scene.add(camera);
  }

  @override
  Widget build(BuildContext context) {
    final cameraController = camera.getComponent<OrbitCameraController>()!;
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Listener(
              onPointerMove: (event) {
                if (event.kind == PointerDeviceKind.mouse &&
                    event.buttons == kSecondaryMouseButton) {
                  const double cameraSpeed = 0.007;
                  setState(() {
                    cameraController.orbitBy(
                      event.delta.dx * cameraSpeed,
                      -event.delta.dy * cameraSpeed,
                    );
                  });
                } else if (event.kind == PointerDeviceKind.mouse &&
                    event.buttons == kMiddleMouseButton) {
                  const double panSpeed = 0.005;
                  setState(() {
                    cameraController.panBy(
                      Offset(
                        -event.delta.dx * panSpeed,
                        event.delta.dy * panSpeed, // Inverted to follow natural hand dragging directions
                      ),
                    );
                  });
                }
              },
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  const double zoomSpeed = 0.005;

                  setState(() {
                    cameraController.dollyBy(event.scrollDelta.dy * zoomSpeed);
                  });
                }
              },
              child: ManipulatableView(
                camera: camera.getComponent<CameraComponent>()!.toCamera(),
                constraints: constraints,
                currentOption: currentOption_,
                child: SceneView(scene),
              ),
            );
          },
        ),
        Container(
          alignment: AlignmentGeometry.bottomRight,
          padding: .all(8),
          child: ManipulationControls(
            options: ManipulationOptions.values.toSet(),
            onChanged: (value) {
              setState(() {
                currentOption_ = value;
              });
            },
          ),
        ),
      ],
    );
  }
}
