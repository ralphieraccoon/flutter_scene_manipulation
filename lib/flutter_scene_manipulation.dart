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

  ManipulatableNode({
    Set<ManipulationOptions>? options,
    super.name,
    super.mesh,
    super.localTransform,
  }) {
    manipulationOptions = options!;

    addAll([
      TranslationGizmo("${name}_translation_gizmo")..visible = false,
      RotationGizmo("${name}_rotation_gizmo")..visible = false,
      ScaleGizmo("${name}_scale_gizmo")..visible = false,
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
  ManipulationOptions currentOption_ = ManipulationOptions.rotatable;

  void setManipulationOption(ManipulationOptions option) =>
      currentOption_ = option;

  @override
  void initState() {
    super.initState();
  }

  vm.Vector3 rayAxisHit(vm.Ray ray, vm.Vector3 axis) {
    final n = ray.direction - axis * ray.direction.dot(axis);
    final d = ray.direction.dot(n);
    final t = d.abs() < 1e-6 ? 0.0 : -ray.origin.dot(n) / d;
    return ray.origin + ray.direction * t;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final ray = widget.camera.screenPointToRay(
          details.localPosition,
          Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
        );

        final hit = widget.child.scene?.raycast(ray);

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
          scene.Node hitNode;

          if (hit.node.parent!.name.contains("gizmo") ||
              hit.node.parent!.parent!.name.contains("gizmo")) {
            if (hit.node.name.endsWith("_shaft") ||
                hit.node.name.endsWith("_tip")) {
              hitNode = hit.node.parent!;
            } else {
              hitNode = hit.node;
            }

            ManipulationAxis axis;

            if (hitNode.name.endsWith("_x")) {
              axis = ManipulationAxis.x;
            } else if (hitNode.name.endsWith("_y")) {
              axis = ManipulationAxis.y;
            } else {
              axis = ManipulationAxis.z;
            }

            print(axis);

            final axisVec = switch (axis) {
              ManipulationAxis.x => vm.Vector3(1, 0, 0),
              ManipulationAxis.y => vm.Vector3(0, 1, 0),
              ManipulationAxis.z => vm.Vector3(0, 0, 1),
            };

            final currLocation = rayAxisHit(currRay, axisVec);
            final prevLocation = rayAxisHit(prevRay, axisVec);

            if (hitNode.parent!.name.contains("rotation_gizmo")) {
              (hitNode.parent! as RotationGizmo).manipulate(
                axis,
                atan2(
                  currLocation.cross(prevLocation).dot(axisVec),
                  currLocation.dot(prevLocation),
                ),
              );
            } else {
              print(
                "manipulating $currLocation $prevLocation ${currLocation.x - prevLocation.x} ${currLocation.y - prevLocation.y} ${currLocation.z - prevLocation.z}",
              );
              (hitNode.parent! as Gizmo).manipulate(
                axis,
                (currLocation - prevLocation).dot(axisVec),
              );
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
      gizmoScale = scale ?? 0.5,
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
    xMaterial = scene.PhysicallyBasedMaterial();
    yMaterial = scene.PhysicallyBasedMaterial();
    zMaterial = scene.PhysicallyBasedMaterial();

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
  TranslationGizmo(super.name, {super.scale, super.style}) {
    xAxis = _createArrow(
      "${name}_x",
      vm.Matrix4.rotationZ(pi / 2),
      super.gizmoScale,
      style.xMaterial,
    );
    yAxis = _createArrow(
      "${name}_y",
      vm.Matrix4.identity(),
      super.gizmoScale,
      style.yMaterial,
    );
    zAxis = _createArrow(
      "${name}_z",
      vm.Matrix4.rotationX(pi / 2),
      super.gizmoScale,
      style.zMaterial,
    );

    _initGizmoNodes();
  }

  scene.Node _createArrow(
    String name,
    vm.Matrix4 transform,
    double scale,
    scene.Material material,
  ) {
    scene.Node shaft = scene.Node(
      name: "${name}_shaft",
      mesh: scene.Mesh(
        scene.CylinderGeometry(
          height: super.gizmoScale,
          topRadius: 0.01,
          bottomRadius: 0.01,
        ),
        material,
      ),
      localTransform: vm.Matrix4.translation(
        vm.Vector3(0.0, super.gizmoScale / 2, 0.0),
      ),
    );
    scene.Node tip = scene.Node(
      name: "${name}_tip",
      mesh: scene.Mesh(
        scene.CylinderGeometry(
          height: super.gizmoScale / 3,
          topRadius: 0,
          bottomRadius: super.gizmoScale / 10,
        ),
        material,
      ),
      localTransform: vm.Matrix4.translation(
        vm.Vector3(0.0, super.gizmoScale, 0.0),
      ),
    );

    return scene.Node(name: name, localTransform: transform)
      ..addAll([shaft, tip]);
  }

  @override
  manipulate(ManipulationAxis axis, double delta) {
    parent?.mutateLocalTransform((matrix) {
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
  RotationGizmo(super.name, {super.scale, super.style}) {
    scene.TorusGeometry ring = scene.TorusGeometry(
      radius: super.gizmoScale,
      tubeRadius: 0.01,
    );

    xAxis = scene.Node(
      name: "${name}_x",
      localTransform: vm.Matrix4.rotationZ(pi / 2),
      mesh: scene.Mesh(ring, style.xMaterial),
    );
    yAxis = scene.Node(
      name: "${name}_y",
      // localTransform: vm.Matrix4.identity(),
      mesh: scene.Mesh(ring, style.yMaterial),
    );
    zAxis = scene.Node(
      name: "${name}_z",
      localTransform: vm.Matrix4.rotationX(pi / 2),
      mesh: scene.Mesh(ring, style.zMaterial),
    );

    _initGizmoNodes();
  }

  @override
  void manipulate(ManipulationAxis axis, double delta) {
    parent?.mutateLocalTransform((matrix) {
      switch (axis) {
        case ManipulationAxis.x:
          matrix.rotateX(delta);
        case ManipulationAxis.y:
          matrix.rotateY(-delta);
        case ManipulationAxis.z:
          matrix.rotateZ(delta);
      }
    });
  }
}

base class ScaleGizmo extends Gizmo {
  ScaleGizmo(super.name, {super.scale, super.style}) {
    xAxis = _createArrow(
      "${name}_x",
      vm.Matrix4.rotationZ(pi / 2),
      super.gizmoScale,
      style.xMaterial,
    );
    yAxis = _createArrow(
      "${name}_y",
      vm.Matrix4.identity(),
      super.gizmoScale,
      style.yMaterial,
    );
    zAxis = _createArrow(
      "${name}_z",
      vm.Matrix4.rotationX(pi / 2),
      super.gizmoScale,
      style.zMaterial,
    );

    _initGizmoNodes();
  }

  scene.Node _createArrow(
    String name,
    vm.Matrix4 transform,
    double scale,
    scene.Material material,
  ) {
    scene.Node shaft = scene.Node(
      name: "${name}_shaft",
      mesh: scene.Mesh(
        scene.CylinderGeometry(
          height: super.gizmoScale,
          topRadius: 0.01,
          bottomRadius: 0.01,
        ),
        material,
      ),
      localTransform: vm.Matrix4.translation(
        vm.Vector3(0.0, super.gizmoScale / 2, 0.0),
      ),
    );
    scene.Node tip = scene.Node(
      name: "${name}_tip",
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
      localTransform: vm.Matrix4.translation(
        vm.Vector3(0.0, super.gizmoScale, 0.0),
      ),
    );

    return scene.Node(name: name, localTransform: transform)
      ..addAll([shaft, tip]);
  }

  @override
  manipulate(ManipulationAxis axis, double delta) {
    parent?.mutateLocalTransform((matrix) {
      switch (axis) {
        case ManipulationAxis.x:
          matrix.scaleByVector3(vm.Vector3(delta, 1.0, 1.0));
        case ManipulationAxis.y:
          matrix.scaleByVector3(vm.Vector3(1.0, delta, 1.0));
        case ManipulationAxis.z:
          matrix.scaleByVector3(vm.Vector3(1.0, 1.0, delta));
      }
    });
  }
}
