using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TestPixelSendCRT : MonoBehaviour
{
    [SerializeField]
    private Material mat;

    // [SerializeField]
    // private CustomRenderTexture crt;

    // Start is called before the first frame update
    void Start()
    {
        InvokeRepeating(nameof(WritePixel), 1.0f, 1.0f);
    }

    void WritePixel()
    {
        Debug.Log("WritePixel");
        mat.SetFloat("_V", Random.value);
        mat.SetInteger("_WR", 1);
        Invoke(nameof(UnWR), 0.2f);
    }

    void UnWR()
    {
        Debug.Log("UnWR");
        mat.SetInteger("_WR", 0);
    }
}
