using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TestPixelSendCRTAnimator : MonoBehaviour
{
    [SerializeField]
    private Animator animator;

    [SerializeField]
    private float tickWait = 0.1f;

    // Start is called before the first frame update
    void Start()
    {
        InvokeRepeating(nameof(WritePixel), 1.0f, tickWait);
    }

    void WritePixel()
    {
        Debug.Log("WritePixel");
        animator.SetInteger("PixelSendCRT/V0", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V1", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V2", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V3", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V4", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V5", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V6", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V7", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V8", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/V9", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/VA", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/VB", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/VC", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/VD", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/VE", (int)(Random.value*255));
        animator.SetInteger("PixelSendCRT/VF", (int)(Random.value*255));

        bool CLK = !animator.GetBool("PixelSendCRT/CLK");
        animator.SetBool("PixelSendCRT/CLK", CLK);
    }
}
