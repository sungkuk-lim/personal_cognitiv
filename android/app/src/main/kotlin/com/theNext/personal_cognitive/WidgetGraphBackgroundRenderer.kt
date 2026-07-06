package com.theNext.personal_cognitive

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader
import kotlin.math.min

/**
 * 위젯 배경용 입체·컬러풀 관계망 — 앱 관계망 팔레트 + 듀얼 허브·그라데이션 엣지·유리구 노드.
 */
internal object WidgetGraphBackgroundRenderer {
    /** 앱 [AppGraphColors] + 보조 액센트 — 위성·글로우용 */
    private val graphPalette = intArrayOf(
        0xFFE91E63.toInt(),
        0xFF00897B.toInt(),
        0xFF7E57C2.toInt(),
        0xFF5C6BC0.toInt(),
        0xFF00BCD4.toInt(),
        0xFFFF7043.toInt(),
        0xFFFFB300.toInt(),
        0xFF26A69A.toInt(),
        0xFFAB47BC.toInt(),
        0xFF42A5F5.toInt(),
    )

    private data class GraphHub(
        val id: Int,
        val nx: Float,
        val ny: Float,
        val depth: Float,
        val radiusDp: Float,
        val tint: Int,
    )

    private data class GraphNode(
        val nx: Float,
        val ny: Float,
        val depth: Float,
        val radiusDp: Float,
        val tint: Int,
        val hubId: Int,
        val isHub: Boolean = false,
    )

    private data class PointF(val x: Float, val y: Float)

    fun render(
        context: Context,
        primaryColor: Int,
        isDark: Boolean,
        widthDp: Int = 480,
        heightDp: Int = 300,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).toInt().coerceAtLeast(1)
        val height = (heightDp * density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        drawNebulaField(canvas, width, height, primaryColor, isDark)
        drawIsoFloorGrid(canvas, width, height, density, isDark)

        val hubs = listOf(
            GraphHub(0, 0.68f, 0.42f, 0.42f, 16f, primaryColor),
            GraphHub(1, 0.16f, 0.20f, 0.78f, 10.5f, graphPalette[0]),
            GraphHub(2, 0.38f, 0.78f, 0.72f, 9f, graphPalette[1]),
        )

        val hubNodes = hubs.map {
            GraphNode(it.nx, it.ny, it.depth, it.radiusDp, it.tint, it.id, isHub = true)
        }
        val hubNodeById = hubNodes.associateBy { it.hubId }
        val hubTintById = hubs.associate { it.id to it.tint }
        val satellites = buildSatellites(hubs)
        val allNodes = satellites + hubNodes
        val projected = allNodes.associateWith { project(it, width, height, density) }
        val hubProjected = hubs.associate { it.id to project(it, width, height, density) }

        for (hub in hubs) {
            val pt = hubProjected[hub.id]!!
            val glowR = hub.radiusDp * density * if (hub.id == 0) 5.2f else 3.6f
            drawHubGlow(canvas, pt.x, pt.y, glowR, hub.tint, isDark, hub.id == 0)
            if (hub.id == 0) {
                drawOrbitalRings(canvas, pt.x, pt.y, hub.radiusDp * density, hub.tint, isDark)
            }
        }

        drawInterHubEdges(canvas, hubs, hubProjected, density, isDark)

        for ((from, to, strength) in buildEdgePairs(satellites, hubNodeById)) {
            val a = projected[from] ?: continue
            val b = projected[to] ?: continue
            val depth = min(from.depth, to.depth)
            val hubTint = hubTintById[from.hubId] ?: primaryColor
            val widthPx = (1.2f + (1f - depth) * 2.2f + strength * 0.5f) * density
            val alpha = if (isDark) 0.28f + (1f - depth) * 0.28f else 0.20f + (1f - depth) * 0.18f
            drawGradientEdge(canvas, a, b, from.tint, hubTint, widthPx, alpha + strength * 0.08f, isDark)
        }

        for (node in allNodes.sortedBy { it.depth }) {
            val pt = projected[node]!!
            val scale = 0.70f + (1f - node.depth) * 0.52f
            val r = node.radiusDp * density * scale
            val shadowDy = (node.depth * 6f + 2.5f) * density
            val shadowAlpha = if (isDark) 0.32f + (1f - node.depth) * 0.20f else 0.16f + (1f - node.depth) * 0.12f
            drawNodeShadow(canvas, pt.x, pt.y + shadowDy, r * 1.15f, shadowAlpha, isDark)
            drawGlassNode(canvas, pt.x, pt.y, r, node.tint, node.depth, isDark, node.isHub)
        }

        drawSoftVignette(canvas, width, height, isDark)
        return bitmap
    }

    private fun buildSatellites(hubs: List<GraphHub>): List<GraphNode> {
        val main = hubs[0].id
        val subA = hubs[1].id
        val subB = hubs[2].id
        val specs = listOf(
            Quad(0.96f, 0.10f, 0.70f, 7.2f, main, 0),
            Quad(0.90f, 0.52f, 0.52f, 7.8f, main, 1),
            Quad(0.54f, 0.08f, 0.64f, 6.8f, main, 2),
            Quad(0.82f, 0.82f, 0.58f, 6.4f, main, 3),
            Quad(0.60f, 0.58f, 0.70f, 5.8f, main, 4),
            Quad(0.98f, 0.38f, 0.78f, 5.2f, main, 5),
            Quad(0.46f, 0.24f, 0.84f, 4.6f, main, 6),
            Quad(0.88f, 0.28f, 0.88f, 4.0f, main, 7),
            Quad(0.04f, 0.06f, 0.86f, 6.2f, subA, 0),
            Quad(0.10f, 0.36f, 0.74f, 6.6f, subA, 2),
            Quad(0.30f, 0.06f, 0.82f, 5.4f, subA, 4),
            Quad(0.02f, 0.48f, 0.92f, 4.8f, subA, 6),
            Quad(0.24f, 0.44f, 0.66f, 5.6f, subA, 8),
            Quad(0.44f, 0.30f, 0.76f, 5.0f, main, 8),
            Quad(0.22f, 0.68f, 0.80f, 5.2f, subB, 1),
            Quad(0.52f, 0.88f, 0.68f, 6.0f, subB, 3),
            Quad(0.68f, 0.72f, 0.74f, 5.4f, subB, 5),
            Quad(0.12f, 0.82f, 0.90f, 4.2f, subB, 7),
            Quad(0.78f, 0.06f, 0.96f, 3.4f, main, 9),
            Quad(0.98f, 0.86f, 0.92f, 3.2f, main, 0),
            Quad(0.58f, 0.38f, 0.86f, 4.4f, subB, 9),
        )
        return specs.map { (nx, ny, depth, radius, hubId, paletteIdx) ->
            GraphNode(
                nx = nx,
                ny = ny,
                depth = depth,
                radiusDp = radius,
                tint = graphPalette[paletteIdx % graphPalette.size],
                hubId = hubId,
            )
        }
    }

    private data class Quad(
        val nx: Float,
        val ny: Float,
        val depth: Float,
        val radiusDp: Float,
        val hubId: Int,
        val paletteIdx: Int,
    )

    private fun buildEdgePairs(
        satellites: List<GraphNode>,
        hubNodeById: Map<Int, GraphNode>,
    ): List<Triple<GraphNode, GraphNode, Float>> {
        val pairs = mutableListOf<Triple<GraphNode, GraphNode, Float>>()
        for (sat in satellites) {
            val hubNode = hubNodeById[sat.hubId] ?: continue
            pairs += Triple(sat, hubNode, 1f)
        }
        val mesh = listOf(
            0 to 5, 1 to 3, 2 to 13, 4 to 1,
            8 to 9, 9 to 12, 10 to 8, 13 to 14,
            14 to 15, 15 to 16, 6 to 7, 0 to 19,
            17 to 18, 20 to 15,
        )
        for ((i, j) in mesh) {
            if (i < satellites.size && j < satellites.size) {
                pairs += Triple(satellites[i], satellites[j], 0.4f)
            }
        }
        return pairs
    }

    private fun project(node: GraphNode, width: Int, height: Int, density: Float): PointF =
        projectRaw(node.nx, node.ny, node.depth, width, height, density)

    private fun project(hub: GraphHub, width: Int, height: Int, density: Float): PointF =
        projectRaw(hub.nx, hub.ny, hub.depth, width, height, density)

    private fun projectRaw(
        nx: Float,
        ny: Float,
        depth: Float,
        width: Int,
        height: Int,
        density: Float,
    ): PointF {
        val isoSkew = 0.30f
        val spreadX = width * 1.22f
        val spreadY = height * 1.08f
        val cx = width * 0.50f
        val cy = height * 0.44f
        val xOff = (nx - 0.5f) * spreadX + (ny - 0.5f) * spreadX * isoSkew
        val yOff = (ny - 0.5f) * spreadY - depth * 34f * density
        return PointF(cx + xOff, cy + yOff)
    }

    private fun drawNebulaField(
        canvas: Canvas,
        width: Int,
        height: Int,
        primaryColor: Int,
        isDark: Boolean,
    ) {
        val blobs = listOf(
            NebulaBlob(0.70f, 0.32f, 0.62f, primaryColor, if (isDark) 0.22f else 0.14f),
            NebulaBlob(0.14f, 0.18f, 0.48f, graphPalette[0], if (isDark) 0.18f else 0.11f),
            NebulaBlob(0.88f, 0.72f, 0.42f, graphPalette[4], if (isDark) 0.16f else 0.10f),
            NebulaBlob(0.36f, 0.78f, 0.38f, graphPalette[1], if (isDark) 0.14f else 0.09f),
            NebulaBlob(0.52f, 0.12f, 0.34f, graphPalette[2], if (isDark) 0.12f else 0.08f),
        )
        for (blob in blobs) {
            val cx = width * blob.nx
            val cy = height * blob.ny
            val radius = min(width, height) * blob.radiusScale
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    cx,
                    cy,
                    radius,
                    intArrayOf(withAlpha(blob.color, blob.alpha), Color.TRANSPARENT),
                    floatArrayOf(0f, 1f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawCircle(cx, cy, radius, paint)
        }
    }

    private data class NebulaBlob(
        val nx: Float,
        val ny: Float,
        val radiusScale: Float,
        val color: Int,
        val alpha: Float,
    )

    private fun drawIsoFloorGrid(canvas: Canvas, width: Int, height: Int, density: Float, isDark: Boolean) {
        val baseY = height * 0.90f
        val span = width * 1.15f
        val gridColors = intArrayOf(graphPalette[4], graphPalette[0], graphPalette[2], graphPalette[1])
        for (i in 0 until 9) {
            val t = i / 8f
            val color = gridColors[i % gridColors.size]
            val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = (0.8f + (1f - t) * 0.4f) * density
                this.color = withAlpha(color, if (isDark) 0.10f + (1f - t) * 0.06f else 0.06f + (1f - t) * 0.04f)
            }
            val x0 = width * 0.5f - span * 0.5f + t * span
            canvas.drawLine(x0, baseY, x0 + span * 0.20f, baseY - height * 0.26f, gridPaint)
        }
        for (i in 0 until 6) {
            val t = i / 5f
            val color = gridColors[(i + 1) % gridColors.size]
            val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 0.75f * density
                this.color = withAlpha(color, if (isDark) 0.08f else 0.05f)
            }
            val leftX = width * (0.04f + t * 0.88f)
            val y = baseY - t * height * 0.22f
            canvas.drawLine(leftX, y, leftX + width * 0.16f, y, gridPaint)
        }
    }

    private fun drawHubGlow(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        color: Int,
        isDark: Boolean,
        isMain: Boolean,
    ) {
        val layers = if (isMain) 4 else 3
        for (i in layers downTo 1) {
            val r = radius * (0.50f + i * 0.26f)
            val alpha = if (isDark) 0.14f + i * 0.11f else 0.08f + i * 0.07f
            val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    cx,
                    cy,
                    r,
                    intArrayOf(withAlpha(color, alpha), withAlpha(color, alpha * 0.35f), Color.TRANSPARENT),
                    floatArrayOf(0f, 0.45f, 1f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawCircle(cx, cy, r, glow)
        }
    }

    private fun drawOrbitalRings(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        hubRadius: Float,
        color: Int,
        isDark: Boolean,
    ) {
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        val ringColors = intArrayOf(color, graphPalette[4], graphPalette[2])
        val radii = floatArrayOf(1.55f, 2.25f, 3.0f, 3.75f)
        val alphas = if (isDark) floatArrayOf(0.32f, 0.22f, 0.14f, 0.08f) else floatArrayOf(0.24f, 0.16f, 0.10f, 0.06f)
        for (i in radii.indices) {
            ringPaint.strokeWidth = hubRadius * 0.09f
            ringPaint.color = withAlpha(ringColors[i % ringColors.size], alphas[i])
            canvas.drawCircle(cx, cy, hubRadius * radii[i], ringPaint)
        }
    }

    private fun drawInterHubEdges(
        canvas: Canvas,
        hubs: List<GraphHub>,
        projected: Map<Int, PointF>,
        density: Float,
        isDark: Boolean,
    ) {
        val links = listOf(0 to 1, 0 to 2, 1 to 2)
        for ((aId, bId) in links) {
            val a = projected[aId] ?: continue
            val b = projected[bId] ?: continue
            val hubA = hubs.first { it.id == aId }
            val hubB = hubs.first { it.id == bId }
            val path = Path().apply {
                moveTo(a.x, a.y)
                val midX = (a.x + b.x) * 0.5f
                val midY = (a.y + b.y) * 0.5f - 16f * density
                quadTo(midX, midY, b.x, b.y)
            }
            val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 3.2f * density
                strokeCap = Paint.Cap.ROUND
                this.color = withAlpha(blendColors(hubA.tint, hubB.tint), if (isDark) 0.10f else 0.07f)
            }
            canvas.drawPath(path, glow)
            val core = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1.6f * density
                strokeCap = Paint.Cap.ROUND
                shader = LinearGradient(
                    a.x,
                    a.y,
                    b.x,
                    b.y,
                    withAlpha(hubA.tint, if (isDark) 0.34f else 0.22f),
                    withAlpha(hubB.tint, if (isDark) 0.34f else 0.22f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawPath(path, core)
        }
    }

    private fun drawGradientEdge(
        canvas: Canvas,
        a: PointF,
        b: PointF,
        colorStart: Int,
        colorEnd: Int,
        strokeWidth: Float,
        alpha: Float,
        isDark: Boolean,
    ) {
        val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth * 2.4f
            strokeCap = Paint.Cap.ROUND
            this.color = withAlpha(blendColors(colorStart, colorEnd), alpha * (if (isDark) 0.35f else 0.25f))
        }
        canvas.drawLine(a.x, a.y, b.x, b.y, glow)
        val core = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth
            strokeCap = Paint.Cap.ROUND
            shader = LinearGradient(
                a.x,
                a.y,
                b.x,
                b.y,
                withAlpha(colorStart, alpha),
                withAlpha(colorEnd, alpha * 0.85f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawLine(a.x, a.y, b.x, b.y, core)
    }

    private fun drawSoftVignette(canvas: Canvas, width: Int, height: Int, isDark: Boolean) {
        val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                width * 0.52f,
                height * 0.42f,
                min(width, height) * 0.78f,
                intArrayOf(Color.TRANSPARENT, withAlpha(Color.BLACK, if (isDark) 0.14f else 0.08f)),
                floatArrayOf(0.55f, 1f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), edge)
    }

    private fun drawNodeShadow(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        alpha: Float,
        isDark: Boolean,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(0xFF000000.toInt(), if (isDark) alpha else alpha * 0.65f)
        }
        canvas.drawCircle(cx, cy, radius, paint)
    }

    private fun drawGlassNode(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        color: Int,
        depth: Float,
        isDark: Boolean,
        isHub: Boolean,
    ) {
        if (isHub) {
            val aura = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    cx,
                    cy,
                    radius * 2.1f,
                    intArrayOf(withAlpha(color, if (isDark) 0.42f else 0.26f), Color.TRANSPARENT),
                    floatArrayOf(0.30f, 1f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawCircle(cx, cy, radius * 2.1f, aura)
        }

        val light = adjustHsv(color, saturationMul = 0.75f, valueMul = 1.18f)
        val core = adjustHsv(color, saturationMul = 1.05f, valueMul = if (isDark) 0.92f else 1.0f)
        val rim = adjustHsv(color, saturationMul = 1.1f, valueMul = if (isDark) 0.72f else 0.82f)
        val bodyAlpha = when {
            isHub -> 0.96f
            depth > 0.9f -> 0.48f
            else -> 0.62f + (1f - depth) * 0.32f
        }

        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                cx - radius * 0.32f,
                cy - radius * 0.36f,
                radius * 1.35f,
                intArrayOf(
                    withAlpha(light, bodyAlpha),
                    withAlpha(core, bodyAlpha * 0.95f),
                    withAlpha(rim, bodyAlpha * 0.88f),
                ),
                floatArrayOf(0f, 0.52f, 1f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawCircle(cx, cy, radius, body)

        val highlight = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = withAlpha(Color.WHITE, if (isDark) 0.38f else 0.52f)
        }
        canvas.drawCircle(cx - radius * 0.32f, cy - radius * 0.36f, radius * 0.34f, highlight)

        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = radius * 0.11f
            this.color = withAlpha(Color.WHITE, if (isDark) 0.20f else 0.28f)
        }
        canvas.drawCircle(cx, cy, radius * 0.94f, stroke)

        if (isHub) {
            val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = radius * 0.13f
                this.color = withAlpha(color, if (isDark) 0.65f else 0.50f)
            }
            canvas.drawCircle(cx, cy, radius * 1.48f, ring)
            val inner = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    cx,
                    cy,
                    radius * 0.42f,
                    intArrayOf(withAlpha(Color.WHITE, if (isDark) 0.75f else 0.90f), withAlpha(color, 0.55f)),
                    floatArrayOf(0f, 1f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawCircle(cx, cy, radius * 0.40f, inner)
        }
    }

    private fun blendColors(a: Int, b: Int): Int {
        val ar = Color.red(a)
        val ag = Color.green(a)
        val ab = Color.blue(a)
        return Color.rgb(
            (ar + Color.red(b)) / 2,
            (ag + Color.green(b)) / 2,
            (ab + Color.blue(b)) / 2,
        )
    }

    private fun adjustHsv(color: Int, saturationMul: Float, valueMul: Float): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[1] = min(1f, hsv[1] * saturationMul)
        hsv[2] = min(1f, hsv[2] * valueMul)
        return Color.HSVToColor(Color.alpha(color), hsv)
    }

    private fun withAlpha(color: Int, alpha: Float): Int {
        val a = (alpha * 255f).toInt().coerceIn(0, 255)
        return (color and 0x00FFFFFF) or (a shl 24)
    }
}
