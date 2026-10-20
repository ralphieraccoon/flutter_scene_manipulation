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
  static const String _kFontPkg = 'flutter_scene_manipulation';

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
    scene.Node meshNode = scene.Node(name: "${name}_mesh", mesh: mesh);
    manipulationOptions = options!;
    mesh = null;

    addAll([
      meshNode,
      TranslationGizmo("${name}_translation_gizmo")..visible = false,
      RotationGizmo("${name}_rotation_gizmo")..visible = false,
      ScaleGizmo("${name}_scale_gizmo")..visible = false,
    ]);
  }

  void setManipulation(ManipulationOptions option) {
    if (!manipulationOptions.contains(option)) return;
    getChildByName("${name}_translation_gizmo")!.visible =
        option == ManipulationOptions.translatable;
    getChildByName("${name}_rotation_gizmo")!.visible =
        option == ManipulationOptions.rotatable;
    getChildByName("${name}_scale_gizmo")!.visible =
        option == ManipulationOptions.scalable;
  }
}

class ManipulationControls extends StatefulWidget {
  final Set<ManipulationOptions> options_;

  final ValueChanged<ManipulationOptions>? onChanged;

  const ManipulationControls({
    super.key,
    Set<ManipulationOptions> options = const {
      ManipulationOptions.freedrag,
      ManipulationOptions.rotatable,
      ManipulationOptions.scalable,
      ManipulationOptions.translatable,
    },
    required this.onChanged,
  }) : options_ = options;

  @override
  State<ManipulationControls> createState() => _ManipulationControlsState();
}

class _ManipulationControlsState extends State<ManipulationControls> {
  @override
  void initState() {
    super.initState();
  }

  static const List<(ManipulationOptions, IconData)> buttons_ = [
    (ManipulationOptions.freedrag, Icons.open_with),
    (ManipulationOptions.translatable, ManipulationIcons.translateicon),
    (ManipulationOptions.rotatable, ManipulationIcons.rotateicon),
    (ManipulationOptions.scalable, ManipulationIcons.scaleicon),
  ];

  ManipulationOptions _selected = ManipulationOptions.freedrag;

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      selectedColor: Colors.white,
      fillColor: Colors.blue[200],
      color: Colors.blue[400],
      borderRadius: const .all(Radius.circular(8)),
      direction: Axis.horizontal,
      isSelected: [for (final (option, _) in buttons_) option == _selected],
      onPressed: (index) {
        setState(() => _selected = buttons_[index].$1);
        widget.onChanged?.call(_selected);
      },
      children: <Widget>[
        Icon(Icons.open_with),
        Icon(ManipulationIcons.translateicon),
        Icon(ManipulationIcons.rotateicon),
        Icon(ManipulationIcons.scaleicon),
      ],
    );
  }
}

class ManipulatableView extends StatefulWidget {
  final scene.Camera camera;
  final BoxConstraints constraints;
  final scene.SceneView child;

  final ManipulationOptions currentOption;

  const ManipulatableView({
    super.key,
    required this.camera,
    required this.constraints,
    required this.child,
    this.currentOption = ManipulationOptions.freedrag,
  });

  @override
  State<ManipulatableView> createState() => _ManipulatableViewState();
}

class _ManipulatableViewState extends State<ManipulatableView> {
  scene.Node? activeNode_;
  // ManipulationOptions currentOption_ = ManipulationOptions.freedrag;
  ManipulationAxis? currentAxis_;
  vm.Vector3? dragAnchor_;
  MouseCursor currentCursor_ = SystemMouseCursors.basic;

  // void setManipulationOption(ManipulationOptions option) =>
  //     currentOption_ = option;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ManipulatableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentOption != oldWidget.currentOption &&
        activeNode_ != null) {
      (activeNode_! as ManipulatableNode).setManipulation(widget.currentOption);
    }
  }

  vm.Vector3 rayPlaneHit(vm.Ray ray, vm.Vector3 point, vm.Vector3 normal) {
    final d = ray.direction.dot(normal);
    final t = d.abs() < 1e-6 ? 0.0 : (point - ray.origin).dot(normal) / d;
    return ray.origin + ray.direction * t;
  }

  vm.Vector3 _worldAxisDirection(scene.Node node, int axis) {
    final t = node.globalTransform;
    return vm.Vector3(
      t.entry(0, axis),
      t.entry(1, axis),
      t.entry(2, axis),
    ).normalized();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: currentCursor_,
      onHover: (details) {
        final ray = widget.camera.screenPointToRay(
          details.localPosition,
          Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
        );

        final hit = widget.child.scene?.raycast(ray);

        setState(() {
          if (hit != null) {
            if (widget.currentOption == ManipulationOptions.freedrag) {
              currentCursor_ = SystemMouseCursors.move;
            } else if (hit.node.name.contains(RegExp(r'_[xyz]'))) {
              currentCursor_ = SystemMouseCursors.click;
            } else {
              currentCursor_ = SystemMouseCursors.basic;
            }
          } else {
            currentCursor_ = SystemMouseCursors.basic;
          }
        });
      },
      child: GestureDetector(
        onTapDown: (details) {
          final ray = widget.camera.screenPointToRay(
            details.localPosition,
            Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
          );

          final hit = widget.child.scene?.raycast(ray);

          if (hit != null && hit.node.parent is ManipulatableNode) {
            activeNode_ = hit.node.parent!;
            (activeNode_ as ManipulatableNode).setManipulation(
              widget.currentOption,
            );
          }
        },
        onPanStart: (details) {
          final ray = widget.camera.screenPointToRay(
            details.localPosition,
            Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
          );

          final hit = widget.child.scene!.raycast(ray);

          if (hit != null) {
            if (hit.node.parent!.name.contains("gizmo") ||
                hit.node.parent!.parent!.name.contains("gizmo")) {
              scene.Node hitNode;

              if (hit.node.name.endsWith("_shaft") ||
                  hit.node.name.endsWith("_tip")) {
                hitNode = hit.node.parent!;
              } else {
                hitNode = hit.node;
              }

              if (hitNode.name.endsWith("_x")) {
                currentAxis_ = ManipulationAxis.x;
              } else if (hitNode.name.endsWith("_y")) {
                currentAxis_ = ManipulationAxis.y;
              } else {
                currentAxis_ = ManipulationAxis.z;
              }
            } else {
              activeNode_ = hit.node.parent;
            }

            dragAnchor_ = activeNode_?.globalTransform.getTranslation();
          }
        },
        onPanUpdate: (details) {
          if (activeNode_ == null) return;

          final currRay = widget.camera.screenPointToRay(
            details.localPosition,
            Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
          );

          final prevRay = widget.camera.screenPointToRay(
            details.localPosition - details.delta,
            Size(widget.constraints.maxWidth, widget.constraints.maxHeight),
          );

          final axisVec = switch (currentAxis_) {
            ManipulationAxis.x => _worldAxisDirection(activeNode_!, 0),
            ManipulationAxis.y => _worldAxisDirection(activeNode_!, 1),
            ManipulationAxis.z => _worldAxisDirection(activeNode_!, 2),
            null => vm.Vector3(0, 0, 0),
          };

          if (activeNode_ == null ||
              dragAnchor_ == null ||
              (widget.currentOption != ManipulationOptions.freedrag &&
                      widget.currentOption == ManipulationOptions.rotatable
                  ? currRay.direction.normalized().dot(axisVec).abs() < 0.02
                  : currRay.direction.normalized().dot(axisVec).abs() > 0.98)) {
            return;
          }

          // final planeNormal = widget.currentOption == ManipulationOptions.freedrag
          //     ? (widget.camera.position - dragAnchor_!).normalized()
          //     : axisVec;

          final vm.Vector3 planeNormal;
          switch (widget.currentOption) {
            case ManipulationOptions.freedrag:
              planeNormal = (widget.camera.position - dragAnchor_!)
                  .normalized();
            case ManipulationOptions.rotatable:
              planeNormal = axisVec; // ring's own plane — unchanged, keep it
            default:
              planeNormal =
                  ((widget.camera.position - dragAnchor_!) -
                          axisVec *
                              (widget.camera.position - dragAnchor_!).dot(
                                axisVec,
                              ))
                      .normalized();
          }

          final currLocation = rayPlaneHit(currRay, dragAnchor_!, planeNormal);
          final prevLocation = rayPlaneHit(prevRay, dragAnchor_!, planeNormal);

          switch (widget.currentOption) {
            case ManipulationOptions.translatable:
              (activeNode_!.getChildByName(
                "${activeNode_!.name}_translation_gizmo",
              ) as TranslationGizmo).manipulate(
                currentAxis_!,
                (currLocation - prevLocation).dot(axisVec),
              );
            case ManipulationOptions.rotatable:
              (activeNode_!.getChildByName(
                "${activeNode_!.name}_rotation_gizmo",
              ) as RotationGizmo).manipulate(
                currentAxis_!,
                atan2(
                  (prevLocation - dragAnchor_!)
                      .cross(currLocation - dragAnchor_!)
                      .dot(axisVec),
                  (currLocation - dragAnchor_!).dot(
                    prevLocation - dragAnchor_!,
                  ),
                ),
              );
            case ManipulationOptions.scalable:
              (activeNode_!.getChildByName(
                "${activeNode_!.name}_scale_gizmo",
              ) as ScaleGizmo).manipulate(
                currentAxis_!,
                (currLocation - prevLocation).dot(axisVec),
              );
            case ManipulationOptions.freedrag:
              if ((activeNode_! as ManipulatableNode).manipulationOptions
                  .contains(ManipulationOptions.freedrag)) {
                final worldDelta = currLocation - prevLocation;
                final localDelta =
                    vm.Matrix4.inverted(activeNode_!.globalTransform)
                        .transform(
                          vm.Vector4(
                            worldDelta.x,
                            worldDelta.y,
                            worldDelta.z,
                            0,
                          ),
                        )
                        .xyz;
                activeNode_!.mutateLocalTransform((matrix) {
                  matrix.translateByVector3(localDelta);
                });
              }
          }
        },
        child: widget.child,
      ),
    );
  }
}

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
      vm.Matrix4.rotationZ(-pi / 2),
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
          matrix.rotateY(delta);
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
      vm.Matrix4.rotationZ(-pi / 2),
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
    parent?.getChildByName("${parent?.name}_mesh")?.mutateLocalTransform((
      matrix,
    ) {
      switch (axis) {
        case ManipulationAxis.x:
          matrix.scaleByVector3(vm.Vector3(1.0 + delta, 1.0, 1.0));
        case ManipulationAxis.y:
          matrix.scaleByVector3(vm.Vector3(1.0, 1.0 + delta, 1.0));
        case ManipulationAxis.z:
          matrix.scaleByVector3(vm.Vector3(1.0, 1.0, 1.0 + delta));
      }
    });
  }
}
