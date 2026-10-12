"""Run in a fresh background Blender process. Never touches the interactive scene."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0))
cube = bpy.context.object
cube.name = "GrowAPlanet_PipelineCube"
cube.data.name = "PipelineCubeMesh"
material = bpy.data.materials.new("PipelineSlate")
material.diffuse_color = (0.23, 0.35, 0.40, 1.0)
cube.data.materials.append(material)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "assets/source/PipelineCube.blend"))
bpy.ops.export_scene.fbx(
    filepath=str(ROOT / "assets/exports/PipelineCube.fbx"),
    use_selection=True, object_types={"MESH"},
    add_leaf_bones=False, bake_anim=False,
)
print(json.dumps({"build": "PASS", "vertices": len(cube.data.vertices), "faces": len(cube.data.polygons)}))
