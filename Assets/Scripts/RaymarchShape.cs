using UnityEngine;

public enum RaymarchShapeType {
    Sphere = 0,
    Cube = 1
}

public class RaymarchShape : MonoBehaviour {
    public RaymarchShapeType shapeType;
    public Color color = Color.white;
    public float blendStrength = 0.2f;
    public bool tiled = false;
    public float tileSize = 5.0f;
}