import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;

enum ManipulationAxis { x, y, z }

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

  void manipulate(ManipulationAxis axis);
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
    xAxis = _createArrow(super.gizmoScale, style.xMaterial);
    yAxis = _createArrow(super.gizmoScale, style.yMaterial);
    zAxis = _createArrow(super.gizmoScale, style.zMaterial);

    _initGizmoNodes();
  }

  scene.Node _createArrow(double scale, scene.Material material) {
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

    return scene.Node()..addAll([shaft, tip]);
  }

  @override
  manipulate(ManipulationAxis axis) {
    // TODO: implement manipulate
    throw UnimplementedError();
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
  void manipulate(ManipulationAxis axis) {
    // TODO: implement manipulate
  }
}

base class ScaleGizmo extends Gizmo {
  ScaleGizmo(super.name) {
    xAxis = _createArrow(super.gizmoScale, style.xMaterial);
    yAxis = _createArrow(super.gizmoScale, style.yMaterial);
    zAxis = _createArrow(super.gizmoScale, style.zMaterial);

    _initGizmoNodes();
  }

  scene.Node _createArrow(double scale, scene.Material material) {
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
          vm.Vector3(super.gizmoScale / 6, super.gizmoScale / 6, super.gizmoScale / 6)
        ),
        material,
      ),
    )..raycastable = false;

    return scene.Node()..addAll([shaft, tip]);
  }

  @override
  manipulate(ManipulationAxis axis) {
    // TODO: implement manipulate
    throw UnimplementedError();
  }
}
