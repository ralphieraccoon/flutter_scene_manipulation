import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;

enum ManipulationAxis { x, y, z }

enum ManipulationOptions { translatable, rotatable, scalable, freedrag }

class ManipulationIcons {
  ManipulationIcons._();

  static const _kFontFam = 'ManipulationIcons';
  static const String? _kFontPkg = null;

  static const IconData rotateicon = IconData(
    0xe800,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData scaleicon = IconData(
    0xe801,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
  static const IconData translateicon = IconData(
    0xe802,
    fontFamily: _kFontFam,
    fontPackage: _kFontPkg,
  );
}

base class ManipulatableNode extends scene.Node {
  Set<ManipulationOptions> manipulationOptions = {};

  ManipulatableNode({Set<ManipulationOptions>? options}) : super() {
    manipulationOptions = options!;

    addAll([
      TranslationGizmo("${name}_translation_gizmo")..visible = false,
      RotationGizmo("${name}_translation_gizmo")..visible = false,
      ScaleGizmo("${name}_translation_gizmo")..visible = false,
    ]);
  }

  void toggleManipulation(ManipulationOptions option) {
    if (manipulationOptions.contains(option)) {
      switch (option) {
        case ManipulationOptions.translatable:
          getChildByName("${name}_translation_gizmo")!
              .visible = !getChildByName("${name}_translation_gizmo")!
              .visible;
          getChildByName("${name}_rotation_gizmo")!.visible = false;
          getChildByName("${name}_scale_gizmo")!.visible = false;
        case ManipulationOptions.rotatable:
          getChildByName("${name}_translation_gizmo")!.visible = false;
          getChildByName("${name}_rotation_gizmo")!
              .visible = !getChildByName("${name}_rotation_gizmo")!
              .visible;
          getChildByName("${name}_scale_gizmo")!.visible = false;
        case ManipulationOptions.scalable:
          getChildByName("${name}_translation_gizmo")!.visible = false;
          getChildByName("${name}_rotation_gizmo")!.visible = false;
          getChildByName("${name}_scale_gizmo")!
              .visible = !getChildByName("${name}_scale_gizmo")!
              .visible;
        default:
      }
    }
  }
}

class ManipulatableView extends StatefulWidget {
  final scene.Camera camera;
  final BoxConstraints constraints;
  final scene.SceneView child;

  const ManipulatableView({
    super.key,
    required this.camera,
    required this.constraints,
    required this.child,
  });

  @override
  State<ManipulatableView> createState() => _ManipulatableViewState();
}

class _ManipulatableViewState extends State<ManipulatableView> {
  late scene.Node activeNode_;
  ManipulationOptions currentOption_ = ManipulationOptions.translatable;

  void setManipulationOption(ManipulationOptions option) =>
      currentOption_ = option;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final ray = widget.camera.screenPointToRay(
          details.localPosition,
          Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
        );

        final hit = widget.child.scene!.raycast(ray);

        if (hit != null && hit.node is ManipulatableNode) {
          activeNode_ = hit.node;
          (activeNode_ as ManipulatableNode).toggleManipulation(currentOption_);
        }
      },
      // onPanStart: (details) {

      //   final ray = widget.camera.screenPointToRay(
      //     details.localPosition,
      //     Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
      //   );

      //   final hit = widget.child.scene!.raycast(ray);

      // },
      onPanUpdate: (details) {
        final currRay = widget.camera.screenPointToRay(
          details.localPosition,
          Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
        );

        final prevRay = widget.camera.screenPointToRay(
          details.localPosition - details.delta,
          Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
        );
        final hit = widget.child.scene!.raycast(currRay);

        if (hit != null) {
          if (hit.node.parent!.name.contains("gizmo")) {
            ManipulationAxis axis;

            if (hit.node.name.endsWith("_x")) {
              axis = ManipulationAxis.x;
            } else if (hit.node.name.endsWith("_y")) {
              axis = ManipulationAxis.y;
            } else {
              axis = ManipulationAxis.z;
            }

            vm.Vector3 currLocation =
                currRay.origin +
                (currRay.direction *
                    switch (axis) {
                      ManipulationAxis.x =>
                        (-currRay.origin.x / currRay.direction.x),
                      ManipulationAxis.y =>
                        (-currRay.origin.y / currRay.direction.y),
                      ManipulationAxis.z =>
                        (-currRay.origin.z / currRay.direction.z),
                    });
            vm.Vector3 prevLocation =
                prevRay.origin +
                (prevRay.direction *
                    switch (axis) {
                      ManipulationAxis.x =>
                        (-prevRay.origin.x / prevRay.direction.x),
                      ManipulationAxis.y =>
                        (-prevRay.origin.y / prevRay.direction.y),
                      ManipulationAxis.z =>
                        (-prevRay.origin.z / prevRay.direction.z),
                    });

            if (hit.node.parent!.name.contains("rotation_gizmo")) {
              (hit.node.parent! as RotationGizmo).manipulate(
                axis,
                atan2(switch (axis) {
                  ManipulationAxis.x => currLocation.cross(prevLocation).x,
                  ManipulationAxis.y => currLocation.cross(prevLocation).y,
                  ManipulationAxis.z => currLocation.cross(prevLocation).z,
                }, currLocation.dot(prevLocation)),
              );
            } else {
              (hit.node.parent! as Gizmo).manipulate(axis, switch (axis) {
                ManipulationAxis.x => (currLocation.x - prevLocation.x),
                ManipulationAxis.y => (currLocation.y - prevLocation.y),
                ManipulationAxis.z => (currLocation.z - prevLocation.z),
              });
            }
          }
        }
      },
      child: widget.child,
    );
  }
}

// @override
// GestureDragStartCallback? get onPanStart {
//   super.onPanStart;
//   return (details) {

// }

// @override
// GestureDragUpdateCallback? get onPanUpdate {
//   super.onPanUpdate;
//   return (details) {};
// }

abstract base class Gizmo extends scene.Node {
  final GizmoStyle style;
  late final scene.Node xAxis;
  late final scene.Node yAxis;
  late final scene.Node zAxis;
  double gizmoScale;

  // The abstract class constructor handles the fallback assignment safely.
  Gizmo(String name, {double? scale, GizmoStyle? style})
    : style =
          style ??
          GizmoStyle.fromColors(
            Colors.red,
            Colors.blue,
            Colors.green,
            stripescale: 100.0,
          ),
      gizmoScale = scale ?? 1.0,
      super(name: name);

  void _initGizmoNodes() {
    addAll([xAxis, yAxis, zAxis]);
  }

  void manipulate(ManipulationAxis axis, double delta);
}

class GizmoStyle {
  late final scene.Material xMaterial;
  late final scene.Material yMaterial;
  late final scene.Material zMaterial;

  GizmoStyle.fromMaterials(
    scene.Material xmaterial,
    scene.Material ymaterial,
    scene.Material zmaterial,
  ) {
    xMaterial = xmaterial;
    yMaterial = ymaterial;
    zMaterial = zmaterial;
  }

  GizmoStyle.fromColors(
    Color xcolor,
    Color ycolor,
    Color zcolor, {
    double? stripescale,
  }) {
    for (var m in [xMaterial, yMaterial, zMaterial]) {
      m = scene.PhysicallyBasedMaterial();
    }
    if (stripescale == null) {
      for (var m in [
        (xMaterial, xcolor),
        (yMaterial, ycolor),
        (zMaterial, zcolor),
      ]) {
        (m.$1 as scene.PhysicallyBasedMaterial).baseColorFactor = vm.Vector4(
          m.$2.r,
          m.$2.g,
          m.$2.b,
          m.$2.a,
        );
      }
    } else {
      for (var m in [
        (xMaterial, xcolor),
        (yMaterial, ycolor),
        (zMaterial, zcolor),
      ]) {
        (m.$1 as scene.PhysicallyBasedMaterial)
          ..baseColorTexture = scene.Texture2D.fromPixels(
            Uint8List.fromList([
              (m.$2.r * 255.0).round().clamp(0, 255),
              (m.$2.g * 255.0).round().clamp(0, 255),
              (m.$2.b * 255.0).round().clamp(0, 255),
              (m.$2.a * 255.0).round().clamp(0, 255),
              (m.$2.r * 255.0 - 50).round().clamp(0, 255),
              (m.$2.g * 255.0 - 50).round().clamp(0, 255),
              (m.$2.b * 255.0 - 50).round().clamp(0, 255),
              (m.$2.a * 255.0).round().clamp(0, 255),
            ]),
            1,
            2,
          )
          ..baseColorTextureTransform = scene.TextureTransform(
            offset: vm.Vector2(0, 0),
            scale: vm.Vector2(1, stripescale),
          );
      }
    }
    for (var m in [xMaterial, yMaterial, zMaterial]) {
      (m as scene.PhysicallyBasedMaterial)
        ..metallicFactor = 1.0
        ..roughnessFactor = 0.25;
    }
  }
}

base class TranslationGizmo extends Gizmo {
  TranslationGizmo(super.name) {
    xAxis = _createArrow("${name}_x", super.gizmoScale, style.xMaterial);
    yAxis = _createArrow("${name}_y", super.gizmoScale, style.yMaterial);
    zAxis = _createArrow("${name}_z", super.gizmoScale, style.zMaterial);

    _initGizmoNodes();
  }

  scene.Node _createArrow(String name, double scale, scene.Material material) {
    scene.Node shaft = scene.Node(
      mesh: scene.Mesh(
        scene.CylinderGeometry(
          height: super.gizmoScale,
          topRadius: 0.1,
          bottomRadius: 0.1,
        ),
        material,
      ),
    )..raycastable = false;
    scene.Node tip = scene.Node(
      mesh: scene.Mesh(
        scene.CylinderGeometry(
          height: super.gizmoScale / 3,
          topRadius: 0,
          bottomRadius: super.gizmoScale / 6,
        ),
        material,
      ),
    )..raycastable = false;

    return scene.Node(name: name)..addAll([shaft, tip]);
  }

  @override
  manipulate(ManipulationAxis axis, double delta) {
    mutateLocalTransform((matrix) {
      switch (axis) {
        case ManipulationAxis.x:
          matrix.translateByVector3(vm.Vector3(delta, 0, 0));
        case ManipulationAxis.y:
          matrix.translateByVector3(vm.Vector3(0, delta, 0));
        case ManipulationAxis.z:
          matrix.translateByVector3(vm.Vector3(0, 0, delta));
      }
    });
  }
}

base class RotationGizmo extends Gizmo {
  RotationGizmo(super.name) {
    scene.TorusGeometry ring = scene.TorusGeometry(
      radius: super.gizmoScale,
      tubeRadius: 0.1,
    );

    xAxis = scene.Node(
      name: "${name}_x",
      localTransform: vm.Matrix4.rotationX(pi / 2),
      mesh: scene.Mesh(ring, style.xMaterial),
    );
    yAxis = scene.Node(
      name: "${name}_y",
      localTransform: vm.Matrix4.rotationY(pi / 2),
      mesh: scene.Mesh(ring, style.yMaterial),
    );
    zAxis = scene.Node(
      name: "${name}_z",
      localTransform: vm.Matrix4.rotationZ(pi / 2),
      mesh: scene.Mesh(ring, style.zMaterial),
    );

    _initGizmoNodes();
  }

  @override
  void manipulate(ManipulationAxis axis, double delta) {
    mutateLocalTransform((matrix) {
      switch (axis) {
        case ManipulationAxis.x:
          matrix.rotateX(delta);
        case ManipulationAxis.y:
          matrix.rotateY(delta);
        case ManipulationAxis.z:
          matrix.rotateZ(delta);
      }
    });
  }
}

base class ScaleGizmo extends Gizmo {
  ScaleGizmo(super.name) {
    xAxis = _createArrow("${name}_x", super.gizmoScale, style.xMaterial);
    yAxis = _createArrow("${name}_y", super.gizmoScale, style.yMaterial);
    zAxis = _createArrow("${name}_z", super.gizmoScale, style.zMaterial);

    _initGizmoNodes();
  }

  scene.Node _createArrow(String name, double scale, scene.Material material) {
    scene.Node shaft = scene.Node(
      mesh: scene.Mesh(
        scene.CylinderGeometry(
          height: super.gizmoScale,
          topRadius: 0.1,
          bottomRadius: 0.1,
        ),
        material,
      ),
    )..raycastable = false;
    scene.Node tip = scene.Node(
      mesh: scene.Mesh(
        scene.CuboidGeometry(
          vm.Vector3(
            super.gizmoScale / 6,
            super.gizmoScale / 6,
            super.gizmoScale / 6,
          ),
        ),
        material,
      ),
    )..raycastable = false;

    return scene.Node(name: name)..addAll([shaft, tip]);
  }

  @override
  manipulate(ManipulationAxis axis, Offset delta) {
    mutateLocalTransform((matrix) {
      switch (axis) {
        case ManipulationAxis.x:
          matrix.scaleByVector3(vm.Vector3(delta, 0, 0));
        case ManipulationAxis.y:
          matrix.scaleByVector3(vm.Vector3(0, delta, 0));
        case ManipulationAxis.z:
          matrix.scaleByVector3(vm.Vector3(0, 0, delta));
      }
    });
  }
}
