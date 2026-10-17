class_name ViperAdminData
extends RefCounted
## One shared set of stores for the admin screens (and tests). Also bridges BrainCore cell commits
## into the global revision log, so brain cells, tickets and wiki edits share one r-number sequence.

static var root := "user://viper"
static var _revs: RevisionStore
static var _tickets: TicketStore
static var _wiki: WikiStore

static func revisions() -> RevisionStore:
	if _revs == null or _revs.root != root:
		_revs = RevisionStore.new(root)
		_tickets = null; _wiki = null
		_revs.register_applier("brain_cell", _apply_brain_cell)
		BrainCore.on_commit = _on_brain_commit
	return _revs

static func tickets() -> TicketStore:
	if _tickets == null: _tickets = TicketStore.new(revisions())
	return _tickets

static func wiki() -> WikiStore:
	if _wiki == null: _wiki = WikiStore.new(revisions())
	return _wiki

static func reset() -> void:
	_revs = null; _tickets = null; _wiki = null
	BrainCore.on_commit = Callable()

## BrainCore -> revision log (path brain/<companion>/<cell_id>)
static func _on_brain_commit(companion: String, cell_id: String, before: Variant, after: Variant, note: String) -> void:
	revisions().commit("brain_cell", "brain/%s/%s" % [companion, cell_id], before, after, note, companion)

## Revert of a brain cell revision = write the old cell back as a learned cell (validated) or remove it.
## Owner only (fix 2026-10-17): a revert changes what a companion has learned, so it needs the same
## unlocked owner session as approving a proposal (EveCore.owner_ok). Before this, "Hold to revert" in
## the admin Timeline could restore or delete a learned cell with the owner session locked.
static func _apply_brain_cell(p: String, content: Variant) -> bool:
	if not EveCore.owner_ok(): return false
	var parts := p.split("/")
	if parts.size() != 3: return false
	var b := BrainCore.new(parts[1], BrainCore._persona_for(parts[1]), BrainCore.adapter_root)
	var learned := b._dir("cells").path_join(parts[2] + ".cell.json")
	if content == null:
		if FileAccess.file_exists(learned): DirAccess.remove_absolute(learned)
		return true
	if not (content is Dictionary) or BrainCell.validate(content, b.allowed_tools) != "": return false
	var f := FileAccess.open(learned, FileAccess.WRITE)
	if f == null: return false   # fix 2026-10-17: missing cells dir used to crash on f.store_string
	f.store_string(JSON.stringify(content, "\t"))
	return true

## World edit summaries (e.g. "terraform 12 voxels at region 3,4") for the timeline; no voxel data.
static func record_world_edit(summary: String, region := "", author := "local") -> int:
	return revisions().commit("world", "world/" + (region if region != "" else "local"), null, summary.left(300), summary.left(120), author)
