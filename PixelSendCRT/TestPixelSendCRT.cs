using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TestPixelSendCRT : MonoBehaviour
{
    [SerializeField]
    private Material mat;

    [SerializeField]
    private float tickWait = 1.0f;

    // Start is called before the first frame update
    void Start()
    {
        InvokeRepeating(nameof(WritePixel), 1.0f, tickWait);
    }

    void WritePixel()
    {
        Debug.Log("WritePixel");
        mat.SetFloat("_V", Random.value);
        int WR = (mat.GetInteger("_WR") != 0) ? 0 : 1;
        mat.SetInteger("_WR", WR);
    }
}
