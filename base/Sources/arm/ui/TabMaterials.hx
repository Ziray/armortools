package arm.ui;

#if (is_paint || is_sculpt)

import haxe.Json;
import zui.Zui;
import zui.Id;
import zui.Nodes;
import iron.system.Time;
import iron.system.Input;
import arm.shader.MakeMaterial;
import arm.data.MaterialSlot;
import arm.util.RenderUtil;
import arm.ProjectFormat;

class TabMaterials {

	@:access(zui.Zui)
	public static function draw(htab: Handle) {
		var ui = UIBase.inst.ui;
		if (ui.tab(htab, tr("Materials"))) {
			ui.beginSticky();
			ui.row([1 / 4, 1 / 4, 1 / 4]);
			if (ui.button(tr("New"))) {
				ui.g.end();
				Context.raw.material = new MaterialSlot(Project.materials[0].data);
				Project.materials.push(Context.raw.material);
				updateMaterial();
				ui.g.begin(false);
				History.newMaterial();
			}

			if (ui.button(tr("Import"))) {
				Project.importMaterial();
			}

			if (ui.button(tr("Nodes"))) {
				UIBase.inst.showMaterialNodes();
			}
			else if (ui.isHovered) ui.tooltip(tr("Show Node Editor") + ' (${Config.keymap.toggle_node_editor})');
			ui.endSticky();
			ui.separator(3, false);

			var slotw = Std.int(51 * ui.SCALE());
			var num = Std.int(Config.raw.layout[LayoutSidebarW] / slotw);

			for (row in 0...Std.int(Math.ceil(Project.materials.length / num))) {
				var mult = Config.raw.show_asset_names ? 2 : 1;
				ui.row([for (i in 0...num * mult) 1 / num]);

				ui._x += 2;
				var off = Config.raw.show_asset_names ? ui.ELEMENT_OFFSET() * 10.0 : 6;
				if (row > 0) ui._y += off;

				for (j in 0...num) {
					var imgw = Std.int(50 * ui.SCALE());
					var i = j + row * num;
					if (i >= Project.materials.length) {
						@:privateAccess ui.endElement(imgw);
						if (Config.raw.show_asset_names) @:privateAccess ui.endElement(0);
						continue;
					}
					var img = ui.SCALE() > 1 ? Project.materials[i].image : Project.materials[i].imageIcon;
					var imgFull = Project.materials[i].image;

					if (Context.raw.material == Project.materials[i]) {
						// ui.fill(1, -2, img.width + 3, img.height + 3, ui.t.HIGHLIGHT_COL); // TODO
						var off = row % 2 == 1 ? 1 : 0;
						var w = 50;
						if (Config.raw.window_scale > 1) w += Std.int(Config.raw.window_scale * 2);
						ui.fill(-1,         -2, w + 3,       2, ui.t.HIGHLIGHT_COL);
						ui.fill(-1,    w - off, w + 3, 2 + off, ui.t.HIGHLIGHT_COL);
						ui.fill(-1,         -2,     2,   w + 3, ui.t.HIGHLIGHT_COL);
						ui.fill(w + 1,      -2,     2,   w + 4, ui.t.HIGHLIGHT_COL);
					}

					#if kha_opengl
					ui.imageInvertY = Project.materials[i].previewReady;
					#end

					var uix = ui._x;
					var uiy = ui._y;
					var tile = ui.SCALE() > 1 ? 100 : 50;
					var state = Project.materials[i].previewReady ? ui.image(img) : ui.image(Res.get("icons.k"), -1, null, tile, tile, tile, tile);
					var isTyping = ui.isTyping || UIView2D.inst.ui.isTyping || UINodes.inst.ui.isTyping;
					if (!isTyping) {
						if (i < 9 && Operator.shortcut(Config.keymap.select_material, ShortcutDown)) {
							var number = Std.string(i + 1) ;
							var width = ui.ops.font.width(ui.fontSize, number) + 10;
							var height = ui.ops.font.height(ui.fontSize);
							ui.g.color = ui.t.TEXT_COL;
							ui.g.fillRect(uix, uiy, width, height);
							ui.g.color = ui.t.ACCENT_COL;
							ui.g.drawString(number, uix + 5, uiy);
						}
					}

					if (state == State.Started && ui.inputY > ui._windowY) {
						if (Context.raw.material != Project.materials[i]) {
							Context.selectMaterial(i);
							#if is_paint
							if (Context.raw.tool == ToolMaterial) {
								function _init() {
									App.updateFillLayers();
								}
								iron.App.notifyOnInit(_init);
							}
							#end
						}
						var mouse = Input.getMouse();
						App.dragOffX = -(mouse.x - uix - ui._windowX - 3);
						App.dragOffY = -(mouse.y - uiy - ui._windowY + 1);
						App.dragMaterial = Context.raw.material;
						if (Time.time() - Context.raw.selectTime < 0.25) {
							UIBase.inst.showMaterialNodes();
							App.dragMaterial = null;
							App.isDragging = false;
						}
						Context.raw.selectTime = Time.time();
					}
					if (ui.isHovered && ui.inputReleasedR) {
						Context.selectMaterial(i);
						var add = Project.materials.length > 1 ? 1 : 0;
						UIMenu.draw(function(ui: Zui) {
							var m = Project.materials[i];

							if (UIMenu.menuButton(ui, tr("To Fill Layer"))) {
								Context.selectMaterial(i);
								App.createFillLayer();
							}

							if (UIMenu.menuButton(ui, tr("Export"))) {
								Context.selectMaterial(i);
								BoxExport.showMaterial();
							}

							#if is_paint
							if (UIMenu.menuButton(ui, tr("Bake"))) {
								Context.selectMaterial(i);
								BoxExport.showBakeMaterial();
							}
							#end

							if (UIMenu.menuButton(ui, tr("Duplicate"))) {
								function _init() {
									Context.raw.material = new MaterialSlot(Project.materials[0].data);
									Project.materials.push(Context.raw.material);
									var cloned = Json.parse(Json.stringify(Project.materials[i].canvas));
									Context.raw.material.canvas = cloned;
									updateMaterial();
									History.duplicateMaterial();
								}
								iron.App.notifyOnInit(_init);
							}

							if (Project.materials.length > 1 && UIMenu.menuButton(ui, tr("Delete"), "delete")) {
								deleteMaterial(m);
							}

							var baseHandle = Id.handle().nest(m.id, {selected: m.paintBase});
							var opacHandle = Id.handle().nest(m.id, {selected: m.paintOpac});
							var norHandle = Id.handle().nest(m.id, {selected: m.paintNor});
							var occHandle = Id.handle().nest(m.id, {selected: m.paintOcc});
							var roughHandle = Id.handle().nest(m.id, {selected: m.paintRough});
							var metHandle = Id.handle().nest(m.id, {selected: m.paintMet});
							var heightHandle = Id.handle().nest(m.id, {selected: m.paintHeight});
							var emisHandle = Id.handle().nest(m.id, {selected: m.paintEmis});
							var subsHandle = Id.handle().nest(m.id, {selected: m.paintSubs});
							UIMenu.menuFill(ui);
							m.paintBase = ui.check(baseHandle, tr("Base Color"));
							UIMenu.menuFill(ui);
							m.paintOpac = ui.check(opacHandle, tr("Opacity"));
							UIMenu.menuFill(ui);
							m.paintNor = ui.check(norHandle, tr("Normal"));
							UIMenu.menuFill(ui);
							m.paintOcc = ui.check(occHandle, tr("Occlusion"));
							UIMenu.menuFill(ui);
							m.paintRough = ui.check(roughHandle, tr("Roughness"));
							UIMenu.menuFill(ui);
							m.paintMet = ui.check(metHandle, tr("Metallic"));
							UIMenu.menuFill(ui);
							m.paintHeight = ui.check(heightHandle, tr("Height"));
							UIMenu.menuFill(ui);
							m.paintEmis = ui.check(emisHandle, tr("Emission"));
							UIMenu.menuFill(ui);
							m.paintSubs = ui.check(subsHandle, tr("Subsurface"));
							if (baseHandle.changed ||
								opacHandle.changed ||
								norHandle.changed ||
								occHandle.changed ||
								roughHandle.changed ||
								metHandle.changed ||
								heightHandle.changed ||
								emisHandle.changed ||
								subsHandle.changed) {
								MakeMaterial.parsePaintMaterial();
								UIMenu.keepOpen = true;
							}
						}, 13 + add);
					}
					if (ui.isHovered) {
						ui.tooltipImage(imgFull);
						if (i < 9) ui.tooltip(Project.materials[i].canvas.name + " - (" + Config.keymap.select_material + " " + (i + 1) + ")");
						else ui.tooltip(Project.materials[i].canvas.name);
					}

					if (Config.raw.show_asset_names) {
						ui._x = uix;
						ui._y += slotw * 0.9;
						ui.text(Project.materials[i].canvas.name, Center);
						if (ui.isHovered) {
							if (i < 9) ui.tooltip(Project.materials[i].canvas.name + " - (" + Config.keymap.select_material + " " + (i + 1) + ")");
							else ui.tooltip(Project.materials[i].canvas.name);
						}
						ui._y -= slotw * 0.9;
						if (i == Project.materials.length - 1) {
							ui._y += j == num - 1 ? imgw : imgw + ui.ELEMENT_H() + ui.ELEMENT_OFFSET();
						}
					}
				}

				ui._y += 6;

				#if kha_opengl
				ui.imageInvertY = false; // Material preview
				#end
			}

			var inFocus = ui.inputX > ui._windowX && ui.inputX < ui._windowX + ui._windowW &&
						  ui.inputY > ui._windowY && ui.inputY < ui._windowY + ui._windowH;
			if (inFocus && ui.isDeleteDown && Project.materials.length > 1) {
				ui.isDeleteDown = false;
				deleteMaterial(Context.raw.material);
			}
		}
	}

	static function updateMaterial() {
		UIHeader.inst.headerHandle.redraws = 2;
		UINodes.inst.hwnd.redraws = 2;
		UINodes.inst.groupStack = [];
		MakeMaterial.parsePaintMaterial();
		RenderUtil.makeMaterialPreview();
		var decal = Context.raw.tool == ToolDecal || Context.raw.tool == ToolText;
		if (decal) RenderUtil.makeDecalPreview();
	}

	static function updateMaterialPointers(nodes: Array<TNode>, i: Int) {
		for (n in nodes) {
			if (n.type == "MATERIAL") {
				if (n.buttons[0].default_value == i) {
					n.buttons[0].default_value = 9999; // Material deleted
				}
				else if (n.buttons[0].default_value > i) {
					n.buttons[0].default_value--; // Offset by deleted material
				}
			}
		}
	}

	public static function acceptSwatchDrag(swatch: TSwatchColor) {
		Context.raw.material = new MaterialSlot(Project.materials[0].data);
		for (node in Context.raw.material.canvas.nodes) {
			if (node.type == "RGB" ) {
				node.outputs[0].default_value = [swatch.base.R, swatch.base.G, swatch.base.B, swatch.base.A];
			}
			else if (node.type == "OUTPUT_MATERIAL_PBR") {
				node.inputs[1].default_value = swatch.opacity;
				node.inputs[2].default_value = swatch.occlusion;
				node.inputs[3].default_value = swatch.roughness;
				node.inputs[4].default_value = swatch.metallic;
				node.inputs[7].default_value = swatch.height;
			}
		}
		Project.materials.push(Context.raw.material);
		updateMaterial();
		History.newMaterial();
	}

	static function deleteMaterial(m: MaterialSlot) {
		var i = Project.materials.indexOf(m);
		for (l in Project.layers) if (l.fill_layer == m) l.fill_layer = null;
		History.deleteMaterial();
		Context.selectMaterial(i == Project.materials.length - 1 ? i - 1 : i + 1);
		Project.materials.splice(i, 1);
		UIBase.inst.hwnds[1].redraws = 2;
		for (m in Project.materials) updateMaterialPointers(m.canvas.nodes, i);
		for (n in m.canvas.nodes) UINodes.onNodeRemove(n);
	}
}

#end
